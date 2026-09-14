import AppIntents
import Foundation

@main
struct FocusFilterTests {
    @MainActor
    static func main() async throws {
        // Exercise the intent's actual activation and deactivation callbacks.
        // System Settings registration and real Focus events are verified on Mac.
        let activation = DuoBarFocusFilter()
        activation.action = .illuminate
        _ = try await activation.perform()
        precondition(FocusFilterReader.state == .active, "Focus activation must light the dot")

        let deactivation = DuoBarFocusFilter()
        precondition(deactivation.action == nil, "An unset parameter must remain nil on deactivation")
        _ = try await deactivation.perform()
        precondition(FocusFilterReader.state == .off, "Focus deactivation must extinguish the dot")

        _ = try await activation.perform()
        precondition(FocusFilterReader.state == .active, "A later Focus must activate again")
        FocusFilterReader.apply(.unavailable(FocusFilterReader.setupHint))
        precondition(!FocusFilterReader.state.isActive, "Unavailable state must never look active")
        precondition(FocusFilterReader.state != .off, "Not configured must remain distinct from off")
        print("PASS: native Focus intent activation, deactivation, reactivation and unavailable state")
    }
}
