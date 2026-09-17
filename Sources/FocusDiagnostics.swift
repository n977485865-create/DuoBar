import Foundation
import Security
import UserNotifications

enum FocusDiagnostics {
    static func capture(completion: @escaping (Result<String, Error>) -> Void) {
        let reading = FocusReader.read()
        var report = reading.diagnosticFields
        report["context"] = "application"
        report["sampledAt"] = ISO8601DateFormatter().string(from: Date())
        report["bundleIdentifier"] = Bundle.main.bundleIdentifier ?? "unavailable"
        report["appVersion"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "unavailable"
        report["appBuild"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "unavailable"
        report["systemVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
        report["communicationNotificationsEntitlement"] = communicationEntitlementStatus()
        let snapshot = report

        // Read existing settings only. Viewing diagnostics must never request notification access.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            var result = snapshot
            result["notificationAuthorization"] = settings.authorizationStatus.rawValue
            result["notificationAuthorizationName"] = notificationAuthorizationName(settings.authorizationStatus)
            let json = Result {
                let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                return String(decoding: data, as: UTF8.self)
            }
            DispatchQueue.main.async { completion(json) }
        }
    }

    private static func notificationAuthorizationName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        @unknown default: return "unknown"
        }
    }

    private static func communicationEntitlementStatus() -> String {
        guard let task = SecTaskCreateFromSelf(nil) else { return "unavailable" }
        var error: Unmanaged<CFError>?
        let value = SecTaskCopyValueForEntitlement(task,
            "com.apple.developer.usernotifications.communication" as CFString, &error)
        if let error {
            let failure = error.takeRetainedValue()
            let domain = (CFErrorGetDomain(failure) as String?) ?? "unknown"
            return "unavailable (\(domain): \(CFErrorGetCode(failure)))"
        }
        guard let value else { return "absent" }
        guard let enabled = value as? Bool else { return "unrecognizedValue" }
        return enabled ? "enabled" : "disabled"
    }
}
