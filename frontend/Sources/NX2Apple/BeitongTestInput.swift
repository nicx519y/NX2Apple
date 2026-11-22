import Foundation
import IOKit.hid

/// Read-only, nonexclusive monitor for the same wired model handled by the Mac game host.
final class BeitongTestInput {
    static let product = "BTP-KP20 NS"
    private var manager: IOHIDManager?
    private var axes: SIMD4<Float>?
    private var received = -Double.infinity
    private var devices = Set<IOHIDDevice>()

    static func decode(_ bytes: UnsafeBufferPointer<UInt8>) -> SIMD4<Float>? {
        guard bytes.count >= 12, bytes[0] == 0x30 else { return nil }
        var axes = SIMD4<Float>()
        for stick in 0..<2 {
            let i = 6 + 3 * stick
            let x = Int(bytes[i]) | (Int(bytes[i + 1] & 15) << 8)
            let y = Int(bytes[i + 1] >> 4) | (Int(bytes[i + 2]) << 4)
            for (offset, raw) in [x, y].enumerated() {
                axes[2 * stick + offset] = Float(raw - 2048) / (raw < 2048 ? 2048 : 2047)
            }
        }
        return axes
    }

    var current: SIMD4<Float>? {
        devices.count == 1 && ProcessInfo.processInfo.systemUptime - received < 1 ? axes : nil
    }

    func start() {
        guard manager == nil else { return }
        let hid = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        manager = hid
        let match: [String: Any] = [kIOHIDVendorIDKey: 0x057e, kIOHIDProductIDKey: 0x2009,
                                    kIOHIDProductKey: Self.product, kIOHIDTransportKey: "USB"]
        IOHIDManagerSetDeviceMatching(hid, match as CFDictionary)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(hid, { ctx, result, _, device in
            guard let ctx, result == kIOReturnSuccess else { return }
            let reader = Unmanaged<BeitongTestInput>.fromOpaque(ctx).takeUnretainedValue()
            reader.devices.insert(device)
            reader.axes = nil
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(hid, { ctx, _, _, device in
            guard let ctx else { return }
            let reader = Unmanaged<BeitongTestInput>.fromOpaque(ctx).takeUnretainedValue()
            reader.devices.remove(device)
            reader.axes = nil
        }, ctx)
        IOHIDManagerRegisterInputReportCallback(hid, { ctx, result, _, type, id, buffer, size in
            guard let ctx, result == kIOReturnSuccess, type == kIOHIDReportTypeInput, id == 0x30,
                  let axes = BeitongTestInput.decode(.init(start: buffer, count: size)) else { return }
            let reader = Unmanaged<BeitongTestInput>.fromOpaque(ctx).takeUnretainedValue()
            guard reader.devices.count == 1 else { return }
            reader.axes = axes
            reader.received = ProcessInfo.processInfo.systemUptime
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        if IOHIDManagerOpen(hid, 0) != kIOReturnSuccess { stop() }
    }

    func stop() {
        guard let hid = manager else { return }
        IOHIDManagerRegisterInputReportCallback(hid, nil, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(hid, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(hid, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(hid, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(hid, 0)
        devices.removeAll()
        axes = nil
        manager = nil
    }

    deinit { stop() }
}
