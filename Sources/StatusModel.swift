import Foundation

enum FocusState: Equatable {
    enum UnavailableReason: Equatable {
        case loading, notDetermined, denied, restricted, noSharedValue, unknownAuthorization

        var title: String {
            switch self {
            case .loading: return "读取中"
            case .notDetermined: return "尚未授权"
            case .denied: return "授权被拒绝"
            case .restricted: return "访问受限制"
            case .noSharedValue: return "共享状态不可用"
            case .unknownAuthorization: return "授权状态未知"
            }
        }

        var detail: String {
            switch self {
            case .loading: return "正在读取专注共享状态。"
            case .notDetermined: return "尚未请求专注状态授权，请点击下方按钮选择是否允许读取。"
            case .denied: return "DuoBar 的专注状态授权被拒绝，请在系统设置中检查授权。"
            case .restricted: return "系统限制 DuoBar 访问专注状态，重新请求授权无法解除此限制。"
            case .noSharedValue: return "已获得专注状态授权，但系统未返回可用的共享状态。可检查共享设置或查看专注诊断。"
            case .unknownAuthorization: return "系统返回了无法识别的授权状态，请查看专注诊断。"
            }
        }
    }

    // These cases describe the shared notification-silencing report, not a global Focus switch.
    case off
    case active
    case unavailable(UnavailableReason)
    var isActive: Bool { self == .active }
    var title: String {
        switch self {
        case .off: return "未报告静音"
        case .active: return "已报告静音"
        case .unavailable(let reason): return reason.title
        }
    }
    var detail: String {
        switch self {
        case .off: return "系统未向 DuoBar 报告通知静音；这不代表所有专注模式都已关闭。"
        case .active: return "系统向 DuoBar 报告了通知静音状态，不包含具体的专注模式。"
        case .unavailable(let reason): return reason.detail
        }
    }
    var authorizationButtonTitle: String {
        switch self {
        case .unavailable(.notDetermined): return "允许读取专注状态…"
        case .unavailable(.denied): return "检查专注授权…"
        case .unavailable(.restricted): return "查看访问限制…"
        case .unavailable(.unknownAuthorization): return "查看授权状态…"
        default: return "刷新专注状态"
        }
    }
    var symbol: String { isActive ? "moon.fill" : "moon" }
    static func shared(_ value: Bool?) -> FocusState {
        guard let value else { return .unavailable(.noSharedValue) }
        return value ? .active : .off
    }
}

struct BatteryState: Equatable {
    var present = false
    var percent: Int?
    var charging = false
    var externalPower = false
    var minutesRemaining: Int?
    var lowPowerMode = false
    // AC can be connected before the battery starts charging, or while charging is paused.
    var connectedToPower: Bool { present && (externalPower || charging) }
    var title: String { percent.map { "\($0)%" } ?? (present ? "读取中" : "外接电源") }
    var detail: String {
        if !present { return "此 Mac 没有内置电池" }
        if charging { return "正在充电" }
        if externalPower { return percent == 100 ? "电量已充满" : "已连接电源 · 未充电" }
        if let minutesRemaining, minutesRemaining > 0 {
            return "电池供电 · 约 \(minutesRemaining / 60) 小时 \(minutesRemaining % 60) 分钟"
        }
        return "电池供电"
    }
}

enum NetworkLink: String { case wifi, ethernet, other, offline, unknown }
struct WiFiState: Equatable {
    var available = false
    var powered = false
    var associated = false
    var ssid: String?
    var rssi: Int?
    var route: NetworkLink = .unknown
    var title: String {
        if associated { return ssid ?? "已连接 Wi-Fi" }
        if route == .ethernet { return "以太网已连接" }
        if !available { return "无 Wi-Fi 接口" }
        return powered ? "Wi-Fi 未连接" : "Wi-Fi 已关闭"
    }
    var detail: String {
        if associated {
            let quality = signalQuality
            return (ssid == nil ? "网络名称受系统保护 · " : "") + quality
        }
        if route == .ethernet { return "正在使用有线网络" }
        return route == .offline ? "没有可用网络路径" : "点开 Wi-Fi 设置管理连接"
    }
    var signalLevel: Int {
        guard associated else { return 0 }
        return rssi.map { $0 >= -60 ? 3 : ($0 >= -72 ? 2 : 1) } ?? 3
    }
    var signalQuality: String {
        guard associated else { return powered ? "未连接" : "已关闭" }
        guard let rssi else { return "已连接" }
        if rssi >= -60 { return "信号很好" }
        if rssi >= -72 { return "信号一般" }
        return "信号较弱"
    }
    var symbol: String {
        if associated { return "wifi" }
        if route == .ethernet { return "network" }
        return powered ? "wifi.exclamationmark" : "wifi.slash"
    }
}

struct VPNState: Equatable {
    var names: [String] = []
    var available = true
    var hasUnidentifiedTunnel = false
    var routedTunnel = false
    var systemProxy = false
    var active: Bool { !names.isEmpty || routedTunnel || systemProxy }
    var title: String {
        if !names.isEmpty { return names.joined(separator: "、") }
        if routedTunnel { return "已连接" }
        if systemProxy { return "系统代理已开启" }
        if !available { return "状态不可用" }
        if hasUnidentifiedTunnel { return "检测到未识别隧道" }
        return "未连接"
    }
}

struct AudioState: Equatable {
    var outputName = "声音输出不可用"
    var headphoneNames: [String] = []
    var muted: Bool?
    var volume: Int?
    var headphoneActive: Bool { !headphoneNames.isEmpty }
    var headphoneTitle: String { headphoneActive ? headphoneNames.joined(separator: "、") : "未连接" }
    var soundTitle: String {
        if muted == true { return "已静音" }
        if let volume { return "\(volume)%" }
        return muted == false ? "未静音" : "设备不提供音量状态"
    }
}

enum StatusGlyph: String, CaseIterable {
    case vpn, headphones, mute, focus
    var title: String {
        switch self {
        case .vpn: return "VPN"
        case .headphones: return "耳机"
        case .mute: return "静音"
        case .focus: return "专注"
        }
    }
    var symbol: String {
        switch self {
        case .vpn: return "key.horizontal"
        case .headphones: return "headphones"
        case .mute: return "speaker.slash.fill"
        case .focus: return "moon.fill"
        }
    }
    func isActive(in status: SystemStatus) -> Bool {
        switch self {
        case .vpn: return status.vpn.active
        case .headphones: return status.audio.headphoneActive
        case .mute: return status.audio.muted == true
        case .focus: return status.focus.isActive
        }
    }
    var label: String {
        switch self {
        case .vpn: return "VPN 已连接"
        case .headphones: return "耳机已连接"
        case .mute: return "已静音"
        case .focus: return "专注共享状态：已报告通知静音"
        }
    }
}

struct SystemStatus: Equatable {
    var battery = BatteryState()
    var wifi = WiFiState()
    var vpn = VPNState()
    var audio = AudioState()
    var focus: FocusState = .unavailable(.loading)
    var glyphs: [StatusGlyph] {
        var items: [StatusGlyph] = []
        if vpn.active { items.append(.vpn) }
        if audio.headphoneActive { items.append(.headphones) }
        if audio.muted == true { items.append(.mute) }
        if focus.isActive { items.append(.focus) }
        return items
    }
    var accessibilitySummary: String {
        (["DuoBar", "电量 \(battery.title)", wifi.title] + glyphs.map(\.label)).joined(separator: "，")
    }
    static func preview() -> SystemStatus {
        var s = SystemStatus()
        s.battery = BatteryState(present: true, percent: 87, charging: false, externalPower: false, minutesRemaining: nil)
        s.wifi = WiFiState(available: true, powered: true, associated: true, ssid: "Home Wi-Fi", rssi: -48, route: .wifi)
        s.vpn.names = ["个人 VPN"]
        s.audio = AudioState(outputName: "AirPods Pro", headphoneNames: ["AirPods Pro"], muted: true, volume: 0)
        s.focus = .active
        return s
    }
}


extension SystemStatus {
    func shouldAnimate(from previous: SystemStatus) -> Bool {
        let old = previous.wifi
        return glyphs != previous.glyphs ||
            wifi.available != old.available || wifi.powered != old.powered ||
            wifi.associated != old.associated || wifi.ssid != old.ssid ||
            wifi.signalLevel != old.signalLevel ||
            (!wifi.associated && wifi.route != old.route)
    }
}
