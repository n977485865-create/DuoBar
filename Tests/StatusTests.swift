import Foundation

@main
struct StatusTests {
    static var checks = 0
    static func check(_ value: @autoclosure () -> Bool, _ description: String) {
        checks += 1
        guard value() else { fputs("FAIL: \(description)\n", stderr); exit(1) }
    }
    static func main() {
        for mask in 0..<16 {
            var s = SystemStatus()
            s.vpn.names = mask & 1 == 0 ? [] : ["VPN"]
            s.audio.headphoneNames = mask & 2 == 0 ? [] : ["AirPods"]
            s.audio.muted = mask & 4 != 0
            s.focus = mask & 8 == 0 ? .off : .active
            check(s.glyphs.count == mask.nonzeroBitCount, "all \(mask) state combinations identify the active dots")
            check(Set(s.glyphs.map(\.label)).count == s.glyphs.count, "no duplicated glyph for mask \(mask)")
        }
        var unknown = SystemStatus()
        unknown.vpn.hasUnidentifiedTunnel = true
        unknown.audio.muted = nil
        unknown.focus = .unavailable("denied")
        check(unknown.glyphs.isEmpty, "unknown states and ordinary tunnels never become active badges")
        check(!unknown.vpn.active, "utun is not VPN evidence")
        check(SystemStatus.preview().glyphs == [.vpn, .headphones, .mute, .focus], "four active states in consistent order")
        check(DotLayout().visible == StatusGlyph.allCases, "all four dots stay visible when inactive")
        let normalized = DotLayout(order: [.focus, .focus, .vpn])
        check(normalized.order == [.focus, .vpn, .headphones, .mute], "partial or duplicated preference order is repaired")
        var layout = DotLayout()
        layout.move(.vpn, by: 1)
        check(layout.visible == [.headphones, .vpn, .mute, .focus], "reorder changes dot positions")
        layout.hidden.insert(.vpn)
        check(layout.visible == [.headphones, .mute, .focus], "hidden VPN leaves other positions ordered")
        layout.hidden = Set(StatusGlyph.allCases)
        check(layout.visible.isEmpty, "all dots can be hidden")
        let suite = "com.corale.duobar.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DotPreferences(defaults: defaults)
        preferences.move(.focus, by: -1)
        preferences.setVisible(false, for: .vpn)
        let restored = DotPreferences(defaults: defaults)
        check(restored.layout.visible == [.headphones, .focus, .mute], "order and hidden states survive reload")
        restored.setVisible(true, for: .vpn)
        check(restored.layout.visible == [.vpn, .headphones, .focus, .mute], "reshown dot retains its chosen order")
        check(!StatusGlyph.focus.isActive(in: unknown), "unshared focus never lights a dot")
        check(StatusGlyph.allCases.allSatisfy { $0.isActive(in: SystemStatus.preview()) }, "each active state lights its own dot")
        let before = SystemStatus.preview()
        check(!before.shouldAnimate(from: before), "unchanged state does not animate")
        var changed = before; changed.battery.percent = 62
        check(!changed.shouldAnimate(from: before), "battery-only update does not animate")
        changed = before; changed.wifi.rssi = -51
        check(!changed.shouldAnimate(from: before), "RSSI noise within one signal level does not animate")
        changed.wifi.rssi = -66
        check(changed.shouldAnimate(from: before), "Wi-Fi signal level change animates")
        changed = before; changed.wifi.ssid = "Another Wi-Fi"
        check(changed.shouldAnimate(from: before), "Wi-Fi network change animates")
        changed = before; changed.wifi.associated = false
        check(changed.shouldAnimate(from: before), "Wi-Fi disconnect animates")
        changed = before; changed.vpn.names = []
        check(changed.shouldAnimate(from: before), "VPN dot change animates")
        changed = before; changed.audio.headphoneNames = []
        check(changed.shouldAnimate(from: before), "headphone dot change animates")
        changed = before; changed.audio.muted = false
        check(changed.shouldAnimate(from: before), "mute dot change animates")
        changed = before; changed.focus = .off
        check(changed.shouldAnimate(from: before), "focus dot change animates")
        func route(_ destination: UInt32, _ mask: UInt32, _ interface: String = "utun4", usable: Bool = true) -> IPv4TunnelRoute {
            IPv4TunnelRoute(interface: interface, destination: destination, mask: mask, usable: usable)
        }
        check(TunnelRoutes.ipv4Value([5, 255, 255, 255, 128], isMask: true) == 0x80000000, "Darwin compact /1 mask with non-address family")
        check(TunnelRoutes.ipv4Value([5, 255, 255, 255, 255], isMask: true) == 0xFF000000, "Darwin compact /8 mask")
        check(TunnelRoutes.ipv4Value([0], isMask: true) == 0, "default route zero-length mask")
        check(TunnelRoutes.ipv4Value([16, 2, 0], isMask: false) == nil, "truncated route address fails closed")
        let mihomo = [route(0x01000000, 0xFF000000), route(0x02000000, 0xFE000000),
            route(0x04000000, 0xFC000000), route(0x08000000, 0xF8000000),
            route(0x10000000, 0xF0000000), route(0x20000000, 0xE0000000),
            route(0x40000000, 0xC0000000), route(0x80000000, 0x80000000)]
        check(TunnelRoutePolicy.activeInterfaces(mihomo) == ["utun4"], "detect Mihomo catch-all routes with reserved-address exclusions")
        check(TunnelRoutePolicy.activeInterfaces([route(0, 0)]).count == 1, "detect tunnel default route")
        check(TunnelRoutePolicy.activeInterfaces([route(0, 0x80000000), route(0x80000000, 0x80000000)]).count == 1, "detect split default VPN")
        check(TunnelRoutePolicy.activeInterfaces([route(0, 0, "en0")]).isEmpty, "ordinary default route is not VPN")
        check(TunnelRoutePolicy.activeInterfaces([route(0, 0, usable: false)]).isEmpty, "scoped or down routes are not active")
        check(TunnelRoutePolicy.activeInterfaces([route(0xA9FE0000, 0xFFFF0000)]).isEmpty, "link-local utun is not VPN")
        check(TunnelRoutePolicy.activeInterfaces(Array(repeating: route(0x01020304, 0xFFFFFFFF), count: 50)).isEmpty, "overlapping host routes never imply catch-all VPN")
        var routed = SystemStatus(); routed.vpn.routedTunnel = true
        check(routed.glyphs == [.vpn], "route-confirmed VPN activates its dot")
        let wifi = WiFiState(available: true, powered: true, associated: true, ssid: nil, rssi: -55, route: .wifi)
        check(wifi.signalQuality == "信号很好", "Wi-Fi signal uses plain language")
        check(wifi.title == "已连接 Wi-Fi", "redacted SSID is still connected")
        check(WiFiState(available: true, powered: false, route: .ethernet).title == "以太网已连接", "Ethernet is not shown as offline")
        check(BatteryState().percent == nil && BatteryState().title == "外接电源", "desktop Mac never fabricates 100 percent")
        check(AudioState().muted == nil, "unsupported mute state is not fabricated")
        print("PASS: \(checks) state combinations and unavailable-data checks")
    }
}
