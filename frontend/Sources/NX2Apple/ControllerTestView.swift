import GameController
import SwiftUI
import NXLauncher
import NXModel

struct TestButtonValue: Equatable, Identifiable {
    var id: String
    var value: Float
    var analog = false
}

struct TestPadState: Equatable {
    var axes = SIMD4<Float>()
    var usb = false
    var buttons: [TestButtonValue] = []

    init() {}

    init(_ pad: GCController, usbAxes: SIMD4<Float>?) {
        let profile = pad.physicalInputProfile
        let left = profile.dpads[GCInputLeftThumbstick], right = profile.dpads[GCInputRightThumbstick]
        axes = usbAxes ?? SIMD4(left?.xAxis.value ?? 0, left?.yAxis.value ?? 0,
                                right?.xAxis.value ?? 0, right?.yAxis.value ?? 0)
        usb = usbAxes != nil
        func add(_ label: String, _ input: GCControllerButtonInput?, analog: Bool = false) {
            guard let input else { return }
            buttons.append(TestButtonValue(id: label, value: analog ? input.value : (input.isPressed ? 1 : 0), analog: analog))
        }
        // On this wired controller Apple's face-button positions are opposite its printed labels.
        let faces = usb ? [GCInputButtonB, GCInputButtonA, GCInputButtonY, GCInputButtonX]
                        : [GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY]
        for (label, key) in zip(["A", "B", "X", "Y"], faces) { add(label, profile.buttons[key]) }
        if let dpad = profile.dpads[GCInputDirectionPad] {
            add("↑", dpad.up)
            add("↓", dpad.down)
            add("←", dpad.left)
            add("→", dpad.right)
        }
        for (label, key) in [("L", GCInputLeftShoulder), ("R", GCInputRightShoulder)] {
            add(label, profile.buttons[key])
        }
        add("ZL / LT", profile.buttons[GCInputLeftTrigger], analog: true)
        add("ZR / RT", profile.buttons[GCInputRightTrigger], analog: true)
        for (label, key) in [("L3", GCInputLeftThumbstickButton), ("R3", GCInputRightThumbstickButton),
                             ("−", GCInputButtonOptions), ("+", GCInputButtonMenu), ("⌂", GCInputButtonHome)] {
            add(label, profile.buttons[key])
        }
    }
}

private final class ControllerTestMonitor: ObservableObject {
    @Published private(set) var pads: [GCController] = []
    @Published var selection: ObjectIdentifier? { didSet { sample() } }
    @Published private(set) var state = TestPadState()
    private let usb = BeitongTestInput()
    private var timer: Timer?

    var showsKunpeng: Bool {
        guard let selected = pads.first(where: { ObjectIdentifier($0) == selection }) else { return false }
        return selected.vendorName == BeitongTestInput.product || selected.vendorName == "BTP-KP40A XINPUT"
    }

    func refresh() {
        pads = GCController.controllers()
        if !pads.contains(where: { ObjectIdentifier($0) == selection }) {
            selection = pads.first.map(ObjectIdentifier.init)
        }
        sample()
    }

    func start() {
        guard timer == nil else { return }
        usb.start()
        refresh()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.sample() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        usb.stop()
        pads = []
        selection = nil
    }

    private func sample() {
        var next = TestPadState()
        if let pad = pads.first(where: { ObjectIdentifier($0) == selection }) {
            let matched = pad.vendorName == BeitongTestInput.product && pad.productCategory == "Switch Pro Controller"
                && !pads.contains { $0 !== pad && $0.vendorName == pad.vendorName }
            next = TestPadState(pad, usbAxes: matched ? usb.current : nil)
        }
        if state != next { state = next }
    }

    deinit { timer?.invalidate() }
}

struct ControllerTestView: View {
    @StateObject private var monitor = ControllerTestMonitor()
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(loc.t("padTest.title")).font(.title2.weight(.semibold))
                Spacer()
                Button(loc.t("console.key.done")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Divider()
            if monitor.pads.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "gamecontroller").font(.largeTitle)
                    Text(loc.t("padTest.wait"))
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 200)
            } else {
                HStack {
                    if monitor.pads.count == 1, let pad = monitor.pads.first {
                        Label(pad.vendorName ?? pad.productCategory, systemImage: "gamecontroller")
                            .font(.headline)
                    } else {
                        Picker(loc.t("padTest.selector"), selection: $monitor.selection) {
                            ForEach(Array(monitor.pads.enumerated()), id: \.element) { index, pad in
                                Text("\(index + 1) · \(pad.vendorName ?? pad.productCategory)")
                                    .tag(Optional(ObjectIdentifier(pad)))
                            }
                        }.fixedSize()
                    }
                    Spacer()
                    Text(loc.t(monitor.state.usb ? "padTest.usb" : "padTest.native"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                if monitor.showsKunpeng {
                    KunpengTestDiagram(state: monitor.state)
                    HStack {
                        coordinates(loc.t("sticks.left"), x: monitor.state.axes.x, y: monitor.state.axes.y)
                        Spacer()
                        coordinates(loc.t("sticks.right"), x: monitor.state.axes.z, y: monitor.state.axes.w)
                    }
                } else {
                    standardInputs
                }
                Text(loc.t("padTest.inputNote")).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(24).frame(width: 580).background(LauncherPalette.background)
        .onAppear { monitor.start() }.onDisappear { monitor.stop() }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in monitor.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in monitor.refresh() }
    }

    private func coordinates(_ title: String, x: Float, y: Float) -> some View {
        HStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: String(format: "X %+.2f   Y %+.2f", x, y)).font(.system(.caption, design: .monospaced))
        }.accessibilityElement(children: .combine)
    }

    @ViewBuilder private var standardInputs: some View {
        HStack(spacing: 12) {
            stick(loc.t("controls.steam.mode.2"), x: monitor.state.axes.x, y: monitor.state.axes.y)
            stick(loc.t("controls.steam.mode.3"), x: monitor.state.axes.z, y: monitor.state.axes.w)
        }
        Text(loc.t("padTest.buttons")).font(.headline)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
            ForEach(monitor.state.buttons) { button in
                let active = button.value > 0.01
                VStack(spacing: 0) {
                    Text(verbatim: button.id).font(.system(size: 13, weight: active ? .bold : .medium))
                    if button.analog {
                        Text(button.value, format: .percent.precision(.fractionLength(0))).font(.caption2.monospacedDigit())
                    }
                }.frame(maxWidth: .infinity).frame(height: 38)
                    .foregroundStyle(active ? LauncherPalette.onCream : Color.primary)
                    .background(active ? LauncherPalette.cream : LauncherPalette.secondaryFill,
                                in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .ignore).accessibilityLabel(button.id)
                    .accessibilityValue(Text(button.value, format: .percent))
            }
        }
    }

    private func stick(_ title: String, x: Float, y: Float) -> some View {
        VStack(spacing: 9) {
            Text(title).font(.headline)
            ZStack {
                Circle().strokeBorder(.secondary.opacity(0.45))
                Rectangle().fill(.secondary.opacity(0.3)).frame(height: 1)
                Rectangle().fill(.secondary.opacity(0.3)).frame(width: 1)
                Circle().fill(LauncherPalette.accent).frame(width: 12, height: 12)
                    .offset(x: CGFloat(x) * 39, y: -CGFloat(y) * 39)
            }.frame(width: 90, height: 90)
            Text(verbatim: String(format: "X %+.2f    Y %+.2f", x, y)).font(.system(.caption, design: .monospaced))
        }.frame(maxWidth: .infinity).padding(12)
            .background(LauncherPalette.card, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
    }
}
