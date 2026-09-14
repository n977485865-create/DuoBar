import AppIntents
import Foundation

enum FocusDotAction: String, AppEnum {
    case illuminate
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "专注圆点"
    static var caseDisplayRepresentations: [FocusDotAction: DisplayRepresentation] = [
        .illuminate: "点亮"
    ]
}

struct DuoBarFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "联动专注圆点"
    static var description: IntentDescription? = "此专注模式开启时点亮 DuoBar 的专注圆点，结束时自动熄灭。"

    // No default: macOS clears optional parameters when the Focus ends.
    @Parameter(title: "专注圆点")
    var action: FocusDotAction?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "联动专注圆点", subtitle: "跟随此专注模式点亮和熄灭")
    }

    func perform() async throws -> some IntentResult {
        await FocusFilterReader.apply(action == .illuminate ? .active : .off)
        return .result()
    }
}

@MainActor
enum FocusFilterReader {
    static let setupHint = "在系统设置 → 专注模式 → 勿扰模式 → 添加过滤条件中选择 DuoBar，将专注圆点设为“点亮”。其他需要联动的模式也需各添加一次。"
    nonisolated static let didChange = Notification.Name("DuoBarFocusFilterDidChange")
    private(set) static var state: FocusState = .unavailable(setupHint)
    private static var reading = false
    private static var revision = 0

    static func apply(_ state: FocusState) {
        revision += 1
        guard self.state != state else { return }
        self.state = state
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func refresh() {
        guard !reading else { return }
        reading = true
        let startedAt = revision
        Task { @MainActor in
            defer { reading = false }
            let value: FocusState
            do {
                let filter = try await DuoBarFocusFilter.current
                value = filter.action == .illuminate ? .active : .off
            } catch SetFocusFilterIntentError.notFound {
                value = .unavailable(setupHint)
            } catch {
                value = .unavailable("暂时无法读取专注过滤条件，请重新打开 DuoBar 或检查系统中的过滤条件。")
            }
            // A delivered transition is newer than a query already in flight.
            guard revision == startedAt else { return }
            apply(value)
        }
    }
}
