import XCTest
import Carbon
@testable import HyprMac

// With Caps Lock remapped to F18, letting go of Ctrl while Caps Lock is held
// makes macOS release F18 right then, and the real release sends no event.
// A keyboard that still reports Caps Lock down keeps the Hypr press going
// until the keyboard itself lets go. Without a keyboard reading, events
// decide exactly as before.

final class CapsLockEarlyReleaseTests: XCTestCase {

    private func key(_ code: Int, down: Bool, flags: CGEventFlags = []) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: down)!
        event.flags = flags
        return event
    }

    private var hypr: Int { Int(HyprKey.capsLock.keyCode) }

    private func manager() -> HotkeyManager {
        let manager = HotkeyManager()
        manager.updateKeybinds(Keybind.defaults)
        return manager
    }

    /// Hypr+T is bound by default, so a swallowed T means Hypr is still held.
    private func hyprIsHeld(_ manager: HotkeyManager) -> Bool {
        manager.handleEvent(.keyDown, key(kVK_ANSI_T, down: true)) == nil
    }

    func testEarlyReleaseWhileTheKeyboardHoldsCapsLockKeepsHypr() {
        let manager = manager()
        manager.notePhysicalCapsLock(device: 1, down: true)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.flagsChanged, key(kVK_Control, down: true, flags: .maskControl))
        // macOS releases F18 as Ctrl is let go
        XCTAssertNil(manager.handleEvent(.keyUp, key(hypr, down: false, flags: .maskControl)))
        _ = manager.handleEvent(.flagsChanged, key(kVK_Control, down: false))

        XCTAssertTrue(hyprIsHeld(manager))
    }

    func testTheKeyboardsOwnReleaseEndsAnEarlyReleasedPress() {
        let manager = manager()
        manager.notePhysicalCapsLock(device: 1, down: true)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))

        manager.notePhysicalCapsLock(device: 1, down: false)

        XCTAssertFalse(hyprIsHeld(manager))
    }

    func testWithoutAKeyboardReadingTheReleaseEndsHyprAsBefore() {
        let manager = manager()
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))

        XCTAssertFalse(hyprIsHeld(manager))
    }

    func testARealReleaseThatTheKeyboardReportsFirstEndsHyprAtOnce() {
        let manager = manager()
        manager.notePhysicalCapsLock(device: 1, down: true)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        manager.notePhysicalCapsLock(device: 1, down: false)
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))

        XCTAssertFalse(hyprIsHeld(manager))
    }

    func testAKeyboardThatGoesAwayEndsThePress() {
        let manager = manager()
        manager.notePhysicalCapsLock(device: 1, down: true)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))
        // removal reports the keyboard as up
        manager.notePhysicalCapsLock(device: 1, down: false)

        XCTAssertFalse(hyprIsHeld(manager))
    }

    func testOnlyTheLastKeyboardHoldingCapsLockEndsThePress() {
        let manager = manager()
        manager.notePhysicalCapsLock(device: 1, down: true)
        manager.notePhysicalCapsLock(device: 2, down: true)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))

        manager.notePhysicalCapsLock(device: 1, down: false)
        XCTAssertTrue(hyprIsHeld(manager))
        manager.notePhysicalCapsLock(device: 2, down: false)
        XCTAssertFalse(hyprIsHeld(manager))
    }

    func testATapInterruptionClearsTheKeyboardReading() {
        let manager = manager()
        manager.notePhysicalCapsLock(device: 1, down: true)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))

        manager.resetTrackingAfterTapInterruption()
        XCTAssertFalse(hyprIsHeld(manager))

        // a later press is judged by events again, not a stale reading
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))
        XCTAssertFalse(hyprIsHeld(manager))
    }

    func testAnotherHyprKeyIgnoresTheCapsLockReading() {
        let manager = manager()
        manager.updateHyprKey(.f19)
        manager.notePhysicalCapsLock(device: 1, down: true)
        _ = manager.handleEvent(.keyDown, key(kVK_F19, down: true))
        _ = manager.handleEvent(.keyUp, key(kVK_F19, down: false))

        XCTAssertFalse(hyprIsHeld(manager))
    }

    func testAnEarlyReleaseIsNeverATap() {
        let manager = manager()
        let tapped = expectation(description: "caps lock tap")
        tapped.isInverted = true
        manager.onCapsLockTap = { tapped.fulfill() }
        manager.notePhysicalCapsLock(device: 1, down: true)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))
        manager.notePhysicalCapsLock(device: 1, down: false)
        wait(for: [tapped], timeout: 0.3)
    }
}
