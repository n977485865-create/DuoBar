import AppKit

final class StatusRow: NSButton {
    var destination: SystemSettings.Page
    var onActivate: (() -> Void)?
    private var hover = false
    private var hoverTracking: NSTrackingArea?
    private let chevron = NSImageView()
    private let symbol = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let detailField = NSTextField(labelWithString: "")
    private let valueField = NSTextField(labelWithString: "")
    override var allowsVibrancy: Bool { true }

    init(height: CGFloat, destination: SystemSettings.Page, compact: Bool = false) {
        self.destination = destination
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: height))
        title = ""
        isBordered = false
        setButtonType(.momentaryChange)
        focusRingType = .default
        target = self; action = #selector(activateRow)
        setAccessibilityIdentifier("status-" + destination.rawValue)
        chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .medium))
        chevron.contentTintColor = .tertiaryLabelColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
        symbol.imageScaling = .scaleProportionallyDown
        titleField.font = .systemFont(ofSize: 13, weight: compact ? .regular : .semibold)
        detailField.font = .systemFont(ofSize: 11)
        detailField.textColor = .secondaryLabelColor
        detailField.lineBreakMode = .byTruncatingTail
        valueField.font = .systemFont(ofSize: 12, weight: .medium)
        valueField.textColor = .secondaryLabelColor
        valueField.alignment = .right
        valueField.lineBreakMode = .byTruncatingMiddle
        valueField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [symbol, titleField, detailField, valueField, chevron].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0)
        }
        NSLayoutConstraint.activate([
            symbol.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            symbol.widthAnchor.constraint(equalToConstant: compact ? 19 : 24),
            symbol.heightAnchor.constraint(equalToConstant: compact ? 19 : 24),
            symbol.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor, constant: compact ? 0 : -8),
            titleField.widthAnchor.constraint(lessThanOrEqualToConstant: compact ? 78 : 145),
            detailField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            detailField.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -10),
            detailField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 3),
            valueField.leadingAnchor.constraint(greaterThanOrEqualTo: titleField.trailingAnchor, constant: 10),
            valueField.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -10),
            valueField.centerYAnchor.constraint(equalTo: titleField.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 8),
            chevron.heightAnchor.constraint(equalToConstant: 12),
            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        detailField.isHidden = compact
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let tracking = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(tracking); hoverTracking = tracking
    }
    override func mouseEntered(with event: NSEvent) { hover = isEnabled; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hover = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        if hover || isHighlighted {
            NSColor.labelColor.withAlphaComponent(isHighlighted ? 0.12 : 0.06).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 1), xRadius: 6, yRadius: 6).fill()
        }
        super.draw(dirtyRect)
    }
    func setNavigationEnabled(_ enabled: Bool) {
        isEnabled = enabled
        chevron.isHidden = !enabled
        if !enabled { hover = false }
        needsDisplay = true
    }
    @objc private func activateRow() { if isEnabled { onActivate?() } }

    func update(symbol name: String, title: String, detail: String = "", value: String = "", active: Bool = true) {
        symbol.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 18, weight: .medium))
        symbol.contentTintColor = active ? .labelColor : .tertiaryLabelColor
        titleField.stringValue = title
        detailField.stringValue = detail
        valueField.stringValue = value
        toolTip = [title, value, detail].filter { !$0.isEmpty }.joined(separator: " · ")
        setAccessibilityElement(true)
        setAccessibilityRole(isEnabled ? .button : .staticText)
        setAccessibilityLabel(toolTip)
        setAccessibilityHelp(isEnabled ? "打开" + destination.title : nil)
        [symbol, titleField, detailField, valueField, chevron].forEach { $0.setAccessibilityElement(false) }
    }
}

final class StatusPanel: NSView {
    static let panelSize = NSSize(width: 314, height: 312)
    var onOpenSettings: ((SystemSettings.Page) -> Void)?
    private let wifi = StatusRow(height: 55, destination: .wifi)
    private let battery = StatusRow(height: 55, destination: .battery)
    private let vpn = StatusRow(height: 35, destination: .vpn, compact: true)
    private let headphones = StatusRow(height: 35, destination: .bluetooth, compact: true)
    private let sound = StatusRow(height: 35, destination: .sound, compact: true)
    private let focus = StatusRow(height: 35, destination: .focus, compact: true)
    private let title = NSTextField(labelWithString: "DuoBar")
    private let mode = NSTextField(labelWithString: "此 Mac")
    override var allowsVibrancy: Bool { true }

    init() {
        super.init(frame: NSRect(origin: .zero, size: Self.panelSize))
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        mode.font = .systemFont(ofSize: 11)
        mode.textColor = .secondaryLabelColor
        let spacer = NSView()
        let header = NSStackView(views: [title, spacer, mode])
        header.orientation = .horizontal; header.alignment = .centerY
        header.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let separator = NSBox()
        separator.boxType = .separator
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let gap = NSView(); gap.heightAnchor.constraint(equalToConstant: 5).isActive = true
        let stack = NSStackView(views: [header, wifi, battery, separator, gap, vpn, headphones, sound, focus])
        stack.orientation = .vertical
        stack.alignment = .leading; stack.spacing = 0
        for row in stack.arrangedSubviews { row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 5)
        ])
        for row in [wifi, battery, vpn, headphones, sound, focus] {
            row.onActivate = { [weak self, weak row] in
                guard let row else { return }
                self?.onOpenSettings?(row.destination)
            }
        }
        vpn.setNavigationEnabled(false)
        update(SystemStatus())
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ state: SystemStatus, preview: Bool = false) {
        mode.stringValue = preview ? "样例状态" : "此 Mac"
        wifi.destination = state.wifi.route == .ethernet && !state.wifi.associated ? .network : .wifi
        wifi.update(symbol: state.wifi.symbol, title: state.wifi.route == .ethernet && !state.wifi.associated ? "以太网" : "Wi-Fi",
                    detail: state.wifi.title, value: state.wifi.associated ? state.wifi.signalQuality : "", active: state.wifi.associated || state.wifi.route == .ethernet)
        wifi.toolTip = state.wifi.detail
        let batterySymbol = state.battery.charging ? "battery.100percent.bolt" : "battery.75percent"
        battery.update(symbol: state.battery.present ? batterySymbol : "powerplug",
                       title: "电池", detail: state.battery.detail, value: state.battery.title)
        vpn.update(symbol: "key.horizontal", title: "VPN", value: state.vpn.title, active: state.vpn.active)
        vpn.toolTip = state.vpn.hasUnidentifiedTunnel ? "检测到网络隧道，但 macOS 未提供可确认的 VPN 名称；不会据此点亮 VPN 图标。" : state.vpn.title
        headphones.update(symbol: "headphones", title: "耳机", value: state.audio.headphoneTitle, active: state.audio.headphoneActive)
        sound.update(symbol: state.audio.muted == true ? "speaker.slash.fill" : "speaker.wave.2",
                     title: "声音", value: state.audio.soundTitle)
        sound.toolTip = state.audio.outputName + " · " + state.audio.soundTitle
        focus.update(symbol: state.focus.symbol, title: "专注", value: state.focus.title, active: state.focus.isActive)
        switch state.focus {
        case .unavailable(let reason): focus.toolTip = reason
        case .active: focus.toolTip = "已绑定的专注模式正在开启。"
        case .off: focus.toolTip = "已绑定的专注模式未开启；未绑定的模式不会点亮此圆点。"
        }
    }
}

final class LargeIconView: NSView {
    var status = SystemStatus.preview() { didSet { needsDisplay = true } }
    var layout = DotLayout() { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        DuoIcon.draw(status: status, layout: layout, in: bounds, color: .labelColor)
    }
}
