import Foundation
import Intents

protocol FocusStatusSource {
    var authorizationStatus: INFocusStatusAuthorizationStatus { get }
    var focusStatus: INFocusStatus { get }
}

extension INFocusStatusCenter: FocusStatusSource {}

struct FocusReading {
    enum AuthorizationAction: Equatable {
        case request, openSettings, explainRestriction, refresh, explainUnknown
    }

    let authorization: INFocusStatusAuthorizationStatus
    let sharedValue: Bool?

    var state: FocusState {
        switch authorization {
        case .notDetermined: return .unavailable(.notDetermined)
        case .denied: return .unavailable(.denied)
        case .restricted: return .unavailable(.restricted)
        case .authorized: return .shared(sharedValue)
        @unknown default: return .unavailable(.unknownAuthorization)
        }
    }

    var authorizationAction: AuthorizationAction {
        switch authorization {
        case .notDetermined: return .request
        case .denied: return .openSettings
        case .restricted: return .explainRestriction
        case .authorized: return .refresh
        @unknown default: return .explainUnknown
        }
    }

    var diagnosticFields: [String: Any] {
        let authorizationName: String
        switch authorization {
        case .notDetermined: authorizationName = "notDetermined"
        case .denied: authorizationName = "denied"
        case .restricted: authorizationName = "restricted"
        case .authorized: authorizationName = "authorized"
        @unknown default: authorizationName = "unknown"
        }
        return [
            "focus": state.title,
            "focusDetail": state.detail,
            "focusAuthorization": authorization.rawValue,
            "focusAuthorizationName": authorizationName,
            "focusSharedValue": sharedValue as Any? ?? NSNull()
        ]
    }
}

enum FocusReader {
    static func read(from source: FocusStatusSource = INFocusStatusCenter.default) -> FocusReading {
        let authorization = source.authorizationStatus
        // Do not query protected state before authorization, or re-read it for diagnostics.
        let value = authorization == .authorized ? source.focusStatus.isFocused : nil
        return FocusReading(authorization: authorization, sharedValue: value)
    }
}
