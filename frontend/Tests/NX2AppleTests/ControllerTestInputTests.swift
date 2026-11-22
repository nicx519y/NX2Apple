import SwiftUI
import XCTest
@testable import NX2Apple

final class ControllerTestInputTests: XCTestCase {
    func testWiredBeitongReportCoversBothHalvesAndReturnsToZero() {
        func axes(_ payload: [UInt8]) -> SIMD4<Float>? {
            ([0x30, 0, 0, 0, 0, 0] + payload).withUnsafeBufferPointer(BeitongTestInput.decode)
        }
        XCTAssertEqual(axes([0, 8, 128, 0, 8, 128]), .zero)
        let low = Float(16 - 2048) / 2048
        XCTAssertEqual(axes([255, 15, 1, 16, 240, 255]), SIMD4(1, low, low, 1))
        XCTAssertEqual(axes([16, 240, 255, 255, 15, 1]), SIMD4(low, 1, 1, low))
        XCTAssertNil(axes([0, 8, 128]))
        XCTAssertNil(Array(repeating: UInt8(0x21), count: 49).withUnsafeBufferPointer(BeitongTestInput.decode))
    }

    @MainActor func testPrintedFaceButtonsShouldersAndStickMovementAppearAtTheirPhysicalPositions() throws {
        func render(_ state: TestPadState) throws -> CGImage {
            let renderer = ImageRenderer(content: KunpengTestDiagram(state: state).frame(width: 500, height: 360))
            renderer.scale = 1
            return try XCTUnwrap(renderer.cgImage)
        }
        func litPixels(_ image: CGImage, at center: CGPoint, radius: Int = 9) throws -> Int {
            let side = CGFloat(radius * 2)
            let area = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(image.cropping(to: area)))
            var count = 0
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    guard let c = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    if c.greenComponent - c.redComponent > 0.25 { count += 1 }
                }
            }
            return count
        }

        let rest = try render(TestPadState())
        let positions: [(String, CGPoint)] = [
            ("A", .init(x: 362, y: 172)), ("B", .init(x: 392, y: 142)),
            ("X", .init(x: 332, y: 142)), ("Y", .init(x: 362, y: 112)),
            ("ZL / LT", .init(x: 131, y: 37)), ("ZR / RT", .init(x: 369, y: 37)),
            ("L3", .init(x: 137, y: 142)), ("R3", .init(x: 310, y: 218))
        ]
        for (id, center) in positions {
            var state = TestPadState()
            state.buttons = [.init(id: id, value: 1)]
            let pressed = try render(state)
            for (other, point) in positions where other != id {
                XCTAssertEqual(try litPixels(pressed, at: point), 0, other)
            }
            XCTAssertGreaterThan(try litPixels(pressed, at: center), 50, id)
        }
        var moved = TestPadState()
        moved.axes = SIMD4(1, 0, 0, -1)
        let sticks = try render(moved)
        for point in [CGPoint(x: 137, y: 142), CGPoint(x: 310, y: 218)] {
            XCTAssertEqual(try litPixels(rest, at: point, radius: 35), 0)
            XCTAssertGreaterThan(try litPixels(sticks, at: point, radius: 35), 60)
        }
    }
}
