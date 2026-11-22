import SwiftUI

/// Front projection of the Kunpeng 40, with the two rear triggers raised into view.
struct KunpengTestDiagram: View {
    let state: TestPadState
    static let design = CGSize(width: 500, height: 360)

    var body: some View {
        Canvas { context, size in
            var drawing = context
            drawing.scaleBy(x: size.width / Self.design.width, y: size.height / Self.design.height)
            Paint(context: drawing, state: state).draw()
        }
        .aspectRatio(Self.design.width / Self.design.height, contentMode: .fit)
        .accessibilityRepresentation {
            VStack {
                ForEach(state.buttons) { button in
                    Text(verbatim: button.id)
                        .accessibilityValue(Text(button.value, format: .percent))
                }
            }
        }
    }

    private struct Paint {
        let context: GraphicsContext
        let state: TestPadState
        let ink = Color(white: 0.13)
        let active = Color(red: 0.39, green: 0.96, blue: 0.76)
        let top = Color(red: 0.92, green: 0.93, blue: 0.94)
        let bottom = Color(red: 0.58, green: 0.61, blue: 0.66)

        // Deepen the housing below the shoulder line. Controls keep their own circular dimensions.
        let housing = CGAffineTransform(a: 1, b: 0, c: 0, d: 1.14, tx: 0, ty: 72 * (1 - 1.14))
        func height(_ y: CGFloat) -> CGFloat { CGPoint(x: 0, y: y).applying(housing).y }

        func draw() {
            trigger("ZL / LT", name: "LT", x: 131)
            trigger("ZR / RT", name: "RT", x: 369)
            shoulder("L", name: "LB", right: false)
            shoulder("R", name: "RB", right: true)
            let shell = Self.shell.applying(housing)
            var shadow = context
            shadow.addFilter(.shadow(color: .black.opacity(0.36), radius: 5, y: 4))
            shadow.fill(shell, with: .color(ink))
            context.fill(shell, with: .linearGradient(.init(colors: [top, .init(white: 0.84), bottom]),
                                                        startPoint: .init(x: 180, y: 68), endPoint: .init(x: 255, y: 309)))
            context.stroke(shell, with: .color(.white.opacity(0.7)), lineWidth: 1.4)
            var panel = Path()
            panel.move(to: .init(x: 84, y: 130))
            panel.addQuadCurve(to: .init(x: 111, y: 88), control: .init(x: 84, y: 99))
            panel.addQuadCurve(to: .init(x: 166, y: 84), control: .init(x: 128, y: 82))
            panel.addLine(to: .init(x: 213, y: 124))
            panel.addLine(to: .init(x: 287, y: 124))
            panel.addLine(to: .init(x: 334, y: 84))
            panel.addQuadCurve(to: .init(x: 389, y: 88), control: .init(x: 372, y: 82))
            panel.addQuadCurve(to: .init(x: 416, y: 130), control: .init(x: 416, y: 99))
            context.stroke(panel.applying(housing), with: .color(.black.opacity(0.17)), lineWidth: 0.9)
            grip(right: false)
            grip(right: true)
            stick("L3", at: .init(x: 137, y: height(133)), x: state.axes.x, y: state.axes.y)
            stick("R3", at: .init(x: 310, y: height(200)), x: state.axes.z, y: state.axes.w)
            dpad()
            for (id, x, y) in [("Y", 362, 103), ("X", 332, 133), ("B", 392, 133), ("A", 362, 163)] {
                key(id, label: id, x: CGFloat(x), y: height(133) + CGFloat(y - 133), width: 27, height: 27)
            }
            key("−", label: "−", x: 197, y: height(110), width: 22, height: 13)
            key("+", label: "+", x: 303, y: height(110), width: 22, height: 13)
            // Turbo is a local hardware control. Only Home sends a host input.
            let turbo = pill(x: 235, y: height(141), width: 19, height: 12)
            context.fill(turbo, with: .color(ink.opacity(0.62)))
            text("T", x: 235, y: height(141), size: 8, color: .white)
            key("⌂", label: "⌂", x: 265, y: height(141), width: 20, height: 13)
        }

        static let shell: Path = {
            var p = Path()
            p.move(to: .init(x: 158, y: 72))
            p.addQuadCurve(to: .init(x: 342, y: 72), control: .init(x: 250, y: 69))
            p.addQuadCurve(to: .init(x: 412, y: 96), control: .init(x: 396, y: 66))
            p.addCurve(to: .init(x: 461, y: 292), control1: .init(x: 443, y: 153), control2: .init(x: 472, y: 261))
            p.addQuadCurve(to: .init(x: 428, y: 302), control: .init(x: 453, y: 321))
            p.addLine(to: .init(x: 353, y: 249))
            p.addQuadCurve(to: .init(x: 343, y: 245), control: .init(x: 348, y: 244))
            p.addLine(to: .init(x: 157, y: 245))
            p.addQuadCurve(to: .init(x: 147, y: 249), control: .init(x: 152, y: 244))
            p.addLine(to: .init(x: 72, y: 302))
            p.addQuadCurve(to: .init(x: 39, y: 292), control: .init(x: 47, y: 321))
            p.addCurve(to: .init(x: 88, y: 96), control1: .init(x: 28, y: 261), control2: .init(x: 57, y: 153))
            p.addQuadCurve(to: .init(x: 158, y: 72), control: .init(x: 104, y: 66))
            p.closeSubpath()
            return p
        }()

        func grip(right: Bool) {
            let pt = { (x: CGFloat, y: CGFloat) in CGPoint(x: right ? 500 - x : x, y: y) }
            var seam = Path()
            seam.move(to: pt(79, 120))
            seam.addQuadCurve(to: pt(80, 193), control: pt(76, 150))
            seam.addLine(to: pt(118, 230))
            seam.move(to: pt(62, 304))
            seam.addLine(to: pt(152, 216))
            context.stroke(seam.applying(housing), with: .color(.black.opacity(0.25)), style: .init(lineWidth: 1.4, lineCap: .round))
            var inlay = Path()
            inlay.move(to: pt(82, 205))
            inlay.addLine(to: pt(111, 234))
            context.stroke(inlay.applying(housing), with: .color(ink), style: .init(lineWidth: 4, lineCap: .round))
        }

        func value(_ id: String) -> Float {
            state.buttons.first(where: { $0.id == id })?.value ?? 0
        }

        func pill(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
            Path(roundedRect: CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height),
                 cornerRadius: min(width, height) / 2)
        }

        func text(_ string: String, x: CGFloat, y: CGFloat, size: CGFloat, color: Color) {
            context.draw(Text(verbatim: string).font(.system(size: size, weight: .semibold, design: .rounded))
                .foregroundColor(color), at: .init(x: x, y: y))
        }

        func cap(_ path: Path, on: Bool) {
            let bounds = path.boundingRect
            let colors = on ? [active, active.opacity(0.92)] : [Color(white: 0.28), ink]
            context.fill(path, with: .linearGradient(.init(colors: colors),
                startPoint: .init(x: bounds.midX, y: bounds.minY), endPoint: .init(x: bounds.midX, y: bounds.maxY)))
            context.stroke(path, with: .color(on ? active : .black.opacity(0.75)), lineWidth: on ? 2.5 : 1.3)
        }

        func key(_ id: String, label: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
            let on = value(id) > 0.01
            let path = pill(x: x, y: y, width: width, height: height)
            context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 4)
            cap(path, on: on)
            text(label, x: x, y: y, size: height > 20 ? 15 : 10, color: on ? ink : .white)
        }

        func trigger(_ id: String, name: String, x: CGFloat) {
            let amount = value(id)
            let y = 37 + 4 * CGFloat(amount)
            let paddle = pill(x: x, y: y, width: 74, height: 24)
            cap(paddle, on: amount > 0.01)
            text(name + "  " + amount.formatted(.percent.precision(.fractionLength(0))),
                 x: x, y: y, size: 12, color: amount > 0.01 ? ink : .white)
        }

        func shoulder(_ id: String, name: String, right: Bool) {
            let pt = { (x: CGFloat, y: CGFloat) in CGPoint(x: right ? 500 - x : x, y: y) }
            var p = Path()
            p.move(to: pt(87, 93))
            p.addQuadCurve(to: pt(151, 53), control: pt(91, 56))
            p.addQuadCurve(to: pt(180, 75), control: pt(166, 51))
            p.closeSubpath()
            let on = value(id) > 0.01
            cap(p, on: on)
            text(name, x: right ? 366 : 134, y: 65, size: 11, color: on ? ink : .white)
        }

        func stick(_ id: String, at center: CGPoint, x: Float, y: Float) {
            let well = pill(x: center.x, y: center.y, width: 70, height: 70)
            context.fill(well, with: .color(ink))
            context.stroke(well, with: .color(.white.opacity(0.9)), lineWidth: 2)
            context.stroke(well, with: .color(Color(white: 0.48)),
                           style: .init(lineWidth: 3, dash: [1, 2.6]))
            let px = center.x + CGFloat(x) * 12, py = center.y - CGFloat(y) * 12
            let tip = pill(x: px, y: py, width: 45, height: 45)
            let pressed = value(id) > 0.01
            cap(tip, on: pressed)
            context.stroke(tip, with: .color(pressed || max(abs(x), abs(y)) > 0.05 ? active : Color(white: 0.63)), lineWidth: 1.8)
            context.stroke(pill(x: px, y: py, width: 37, height: 37),
                           with: .color(.white.opacity(0.14)), lineWidth: 0.9)
            text(id, x: px, y: py, size: 11, color: pressed ? ink : .white)
        }

        func dpad() {
            let base = pill(x: 193, y: height(195), width: 62, height: 62)
            context.fill(base, with: .color(ink))
            context.stroke(base, with: .color(.white.opacity(0.65)), lineWidth: 2)
            for (id, x, y) in [("↑", 193, 177), ("↓", 193, 213), ("←", 175, 195), ("→", 211, 195)] {
                let on = value(id) > 0.01
                let row = height(195) + CGFloat(y - 195)
                let tile = Path(roundedRect: CGRect(x: CGFloat(x - 9), y: row - 9, width: 18, height: 18), cornerRadius: 4)
                cap(tile, on: on)
                text(id, x: CGFloat(x), y: row, size: 14, color: on ? ink : .white)
            }
        }
    }
}
