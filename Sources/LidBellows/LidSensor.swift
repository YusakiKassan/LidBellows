import Foundation
import IOKit.hid

/// Reads the MacBook hinge angle through an undocumented HID device: Apple vendor 0x05AC,
/// sensor usage page 0x20, usage 0x8A. Feature report 7 gives hundredths of a degree
/// (32-bit little endian after the report ID); older firmware may only answer report 1,
/// whole degrees as 16-bit little endian. The protocol was worked out by
/// github.com/samhenrigold/LidAngleSensor; this is an independent implementation.
final class LidSensor {
    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let reportID: CFIndex

    init?() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDPrimaryUsagePageKey: 0x20,
            kIOHIDPrimaryUsageKey: 0x8A,
        ] as CFDictionary)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>
        else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return nil
        }
        for device in devices {
            for reportID: CFIndex in [7, 1] where Self.read(device, reportID: reportID) != nil {
                self.manager = manager
                self.device = device
                self.reportID = reportID
                return
            }
        }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        return nil
    }

    deinit {
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    var isPrecise: Bool { reportID == 7 }

    /// Degrees, 0 = closed. Nil if the read failed.
    func readAngle() -> Double? {
        Self.read(device, reportID: reportID)
    }

    private static func read(_ device: IOHIDDevice, reportID: CFIndex) -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(report.count)
        let status = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, reportID, &report, &length)
        guard status == kIOReturnSuccess else { return nil }
        let angle: Double
        if reportID == 7 {
            guard length >= 5 else { return nil }
            let raw = UInt32(report[1]) | UInt32(report[2]) << 8 | UInt32(report[3]) << 16 | UInt32(report[4]) << 24
            angle = Double(raw) / 100
        } else {
            guard length >= 3 else { return nil }
            angle = Double(UInt16(report[1]) | UInt16(report[2]) << 8)
        }
        return (0...200).contains(angle) ? angle : nil
    }
}
