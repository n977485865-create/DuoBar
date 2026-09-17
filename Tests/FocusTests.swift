import Foundation
import Intents

private final class FocusSource: FocusStatusSource {
    var authorization: INFocusStatusAuthorizationStatus
    var value: Bool?
    var authorizationReads = 0
    var valueReads = 0

    init(_ authorization: INFocusStatusAuthorizationStatus, _ value: Bool?) {
        self.authorization = authorization
        self.value = value
    }

    var authorizationStatus: INFocusStatusAuthorizationStatus {
        authorizationReads += 1
        return authorization
    }
    var focusStatus: INFocusStatus {
        valueReads += 1
        return INFocusStatus(isFocused: value)
    }
}

@main
struct FocusTests {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard value() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }

    static func main() throws {
        let deniedCases: [(INFocusStatusAuthorizationStatus, FocusState.UnavailableReason, FocusReading.AuthorizationAction)] = [
            (.notDetermined, .notDetermined, .request),
            (.denied, .denied, .openSettings),
            (.restricted, .restricted, .explainRestriction)
        ]
        var failureTitles = Set<String>()
        for (authorization, reason, action) in deniedCases {
            let source = FocusSource(authorization, true)
            let reading = FocusReader.read(from: source)
            check(reading.state == .unavailable(reason), "authorization failures keep their reason")
            check(reading.authorizationAction == action, "only undetermined authorization can prompt")
            check(source.authorizationReads == 1, "authorization is sampled once")
            check(source.valueReads == 0, "unapproved sources are not queried for protected values")
            check(reading.sharedValue == nil, "unapproved values are not published")
            check(!reading.state.isActive, "authorization failures never light the dot")
            failureTitles.insert(reading.state.title)
        }
        check(failureTitles.count == deniedCases.count, "permission failures have distinct visible titles")

        for value: Bool? in [true, false, nil] {
            let source = FocusSource(.authorized, value)
            let reading = FocusReader.read(from: source)
            check(reading.sharedValue == value, "authorized optional values are preserved")
            check(source.authorizationReads == 1 && source.valueReads == 1, "a reading samples each API once")
            check(reading.authorizationAction == .refresh, "authorized users refresh instead of reauthorizing")
            check(reading.state.isActive == (value == true), "only an explicit positive report lights the dot")

            // Diagnostics must keep the original reading even if the source changes afterwards.
            source.authorization = .denied
            source.value = !(value ?? false)
            let fields = reading.diagnosticFields
            let data = try JSONSerialization.data(withJSONObject: fields)
            let decoded = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            check(decoded["focusAuthorization"] as? Int == INFocusStatusAuthorizationStatus.authorized.rawValue,
                  "diagnostics use the sampled authorization")
            check(decoded["focusAuthorizationName"] as? String == "authorized", "diagnostics explain the authorization enum")
            check(decoded["focus"] as? String == reading.state.title, "diagnostics and visible state use one reading")
            if let value {
                check(decoded["focusSharedValue"] as? Bool == value, "JSON preserves both true and false")
            } else {
                check(decoded["focusSharedValue"] is NSNull, "JSON preserves unavailable as null")
                check(reading.state == .unavailable(.noSharedValue), "authorized nil stays distinct from denied")
            }
            check(source.authorizationReads == 1 && source.valueReads == 1, "diagnostics do not query a second snapshot")
        }

        check(FocusState.off.title == "未报告静音", "false must not claim the system Focus switch is off")
        check(FocusState.active.title == "已报告静音", "true describes the notification-silencing report")
        check(FocusState.off.detail.contains("不代表"), "the negative report explains its scope")
        check(FocusState.unavailable(.noSharedValue).detail.contains("已获得"), "authorized nil does not ask to reauthorize")
        check(FocusState.unavailable(.notDetermined).authorizationButtonTitle == "允许读取专注状态…",
              "undetermined authorization offers a request")
        check(FocusState.unavailable(.noSharedValue).authorizationButtonTitle == "刷新专注状态",
              "authorized nil offers refresh")
        check(!FocusState.unavailable(.unknownAuthorization).isActive, "unknown authorization stays unavailable")
        print("PASS: \(checks) Focus authorization, shared-state and diagnostic snapshot checks")
    }
}
