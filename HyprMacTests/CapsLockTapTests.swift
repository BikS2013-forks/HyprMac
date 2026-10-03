import XCTest
import Carbon
@testable import HyprMac

// Caps Lock is remapped to F18 to act as the Hypr key. Tapped on its own it
// still toggles Caps Lock; a chord, a mouse press or a long hold never does.

final class CapsLockTapTests: XCTestCase {

    private func key(_ code: Int, down: Bool, flags: CGEventFlags = []) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: down)!
        event.flags = flags
        return event
    }

    private var hypr: Int { Int(HyprKey.capsLock.keyCode) }

    private func manager(expectingTap: Bool) -> (HotkeyManager, XCTestExpectation) {
        let manager = HotkeyManager()
        manager.updateKeybinds(Keybind.defaults)
        let tapped = expectation(description: "caps lock tap")
        tapped.isInverted = !expectingTap
        manager.onCapsLockTap = { tapped.fulfill() }
        return (manager, tapped)
    }

    func testABareTapTogglesCapsLock() {
        let (manager, tapped) = manager(expectingTap: true)
        XCTAssertNil(manager.handleEvent(.keyDown, key(hypr, down: true)))
        XCTAssertNil(manager.handleEvent(.keyUp, key(hypr, down: false)))
        wait(for: [tapped], timeout: 0.5)
    }

    func testAChordIsNotATap() {
        let (manager, tapped) = manager(expectingTap: false)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyDown, key(kVK_ANSI_T, down: true))
        _ = manager.handleEvent(.keyUp, key(kVK_ANSI_T, down: false))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))
        wait(for: [tapped], timeout: 0.3)
    }

    func testAnUnboundKeyDuringThePressIsNotATapEither() {
        let (manager, tapped) = manager(expectingTap: false)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyDown, key(kVK_ANSI_Z, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))
        wait(for: [tapped], timeout: 0.3)
    }

    func testAModifierDuringThePressIsNotATap() {
        let (manager, tapped) = manager(expectingTap: false)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.flagsChanged, key(kVK_Shift, down: true, flags: .maskShift))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))
        wait(for: [tapped], timeout: 0.3)
    }

    func testAMousePressDuringThePressIsNotATap() {
        let (manager, tapped) = manager(expectingTap: false)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        manager.noteHyprPressUsed()
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))
        wait(for: [tapped], timeout: 0.3)
    }

    func testAutorepeatDoesNotRestartThePress() {
        let (manager, tapped) = manager(expectingTap: false)
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyDown, key(kVK_ANSI_T, down: true))
        // the held Hypr key repeats: still the same, already-used press
        _ = manager.handleEvent(.keyDown, key(hypr, down: true))
        _ = manager.handleEvent(.keyUp, key(hypr, down: false))
        wait(for: [tapped], timeout: 0.3)
    }

    func testTheTapWindow() {
        XCTAssertTrue(HotkeyManager.isBareTap(heldFor: 0.12, used: false))
        XCTAssertTrue(HotkeyManager.isBareTap(heldFor: HotkeyManager.bareTapMaxDuration, used: false))
        XCTAssertFalse(HotkeyManager.isBareTap(heldFor: 0.9, used: false), "a long hold is a change of mind")
        XCTAssertFalse(HotkeyManager.isBareTap(heldFor: 0.1, used: true))
    }
}
