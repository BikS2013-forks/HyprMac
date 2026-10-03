// Caps Lock as each keyboard itself reports it, below the Caps Lock → F18
// remap. HotkeyManager uses it to tell an early F18 release from a real one.

import Foundation
import IOKit.hid

/// Reads the Caps Lock key straight from every keyboard through
/// `IOHIDManager`, beneath the `hidutil` remap and beneath the event stream.
///
/// Why: with Caps Lock remapped to F18, letting go of Ctrl while Caps Lock
/// is still held makes macOS send an F18 key-up at that moment, and the
/// real release later sends nothing (live, 2026-10-04: the F18 key-up came
/// 0.2 ms before the Ctrl release, with the keyboard still reporting the
/// key down until it was let go). The event stream alone cannot tell that
/// release from a real one; this can.
///
/// Only Caps Lock values are delivered (input value matching), so no other
/// keystroke is read. Reading keyboards needs Input Monitoring; without it
/// the monitor does not start and HotkeyManager works from events alone.
final class PhysicalCapsLockMonitor {
    typealias DeviceID = Int

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private let onKey: (DeviceID, Bool) -> Void
    private let onRemoval: (DeviceID) -> Void
    private var scheduledRunLoop: CFRunLoop?

    /// `onKey` gets a keyboard and whether its Caps Lock is down;
    /// `onRemoval` a keyboard that went away. Both run on the run loop the
    /// monitor is opened on.
    init(onKey: @escaping (DeviceID, Bool) -> Void,
         onRemoval: @escaping (DeviceID) -> Void) {
        self.onKey = onKey
        self.onRemoval = onRemoval
    }

    /// Whether Input Monitoring is granted. Asks once when macOS has no
    /// answer yet; the prompt answers later, so a first launch returns false
    /// and the monitor starts on the next one. Call on main: never on the
    /// event tap's thread, which holds every keystroke while it is busy.
    static func accessGranted() -> Bool {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted:
            return true
        case kIOHIDAccessTypeDenied:
            hyprLog(.notice, .hotkey, "physical caps lock: Input Monitoring denied — events only")
            return false
        default:
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            hyprLog(.notice, .hotkey, "physical caps lock: Input Monitoring requested, granted=\(granted)")
            return granted
        }
    }

    /// Open every keyboard, delivering on `runLoop`. False when the manager
    /// will not open; nothing is left scheduled then.
    func open(on runLoop: CFRunLoop) -> Bool {
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ] as CFDictionary)
        IOHIDManagerSetInputValueMatching(manager, [
            kIOHIDElementUsagePageKey: kHIDPage_KeyboardOrKeypad,
            kIOHIDElementUsageKey: kHIDUsage_KeyboardCapsLock
        ] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            let element = IOHIDValueGetElement(value)
            guard IOHIDElementGetUsagePage(element) == UInt32(kHIDPage_KeyboardOrKeypad),
                  IOHIDElementGetUsage(element) == UInt32(kHIDUsage_KeyboardCapsLock) else { return }
            let monitor = Unmanaged<PhysicalCapsLockMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.onKey(PhysicalCapsLockMonitor.id(IOHIDElementGetDevice(element)), IOHIDValueGetIntegerValue(value) != 0)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let monitor = Unmanaged<PhysicalCapsLockMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.onRemoval(PhysicalCapsLockMonitor.id(device))
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, runLoop, CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, runLoop, CFRunLoopMode.commonModes.rawValue)
            hyprLog(.notice, .hotkey, "physical caps lock: keyboards would not open (\(result)) — events only")
            return false
        }
        scheduledRunLoop = runLoop
        hyprLog(.notice, .hotkey, "physical caps lock: reading keyboards")
        return true
    }

    /// Close the keyboards. Call on the run loop's own thread.
    func close() {
        guard let runLoop = scheduledRunLoop else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, runLoop, CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        scheduledRunLoop = nil
    }

    private static func id(_ device: IOHIDDevice) -> DeviceID {
        Int(bitPattern: Unmanaged.passUnretained(device).toOpaque())
    }
}
