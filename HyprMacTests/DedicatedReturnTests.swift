import XCTest
import Cocoa
@testable import HyprMac

// Hypr+F is a toggle: the second press puts the window back in the slot and
// at the ratios it left, when its old workspace has not changed meanwhile.

final class DedicatedReturnTests: XCTestCase {

    private var engine: TilingEngine!
    private var screen: NSScreen!

    override func setUpWithError() throws {
        let dm = DisplayManager()
        guard let first = dm.screens.first else { throw XCTSkip("test requires a display") }
        screen = first
        engine = TilingEngine(displayManager: dm, frameSizingIOFactory: acceptingFrameSizingIOFactory())
    }

    private func ids(_ workspace: Int) -> [CGWindowID]? {
        engine.existingTree(forWorkspace: workspace, screen: screen)?.allWindows.map(\.windowID)
    }

    /// 1 | (2 / 3) on ws1 with user ratios, then 2 goes to ws2 the way
    /// Hypr+F sends it.
    private func sendMiddleWindowAway() -> (w1: HyprWindow, w2: HyprWindow, w3: HyprWindow) {
        let w1 = makeWindow(id: 1), w2 = makeWindow(id: 2), w3 = makeWindow(id: 3)
        engine.prepareTileLayout([w1, w2, w3], onWorkspace: 1, screen: screen)
        let root = engine.existingTree(forWorkspace: 1, screen: screen)!.root
        root.splitRatio = 0.4; root.userSetRatio = true
        root.right?.splitRatio = 0.3; root.right?.userSetRatio = true

        engine.rememberDedicatedReturn(w2, fromWorkspace: 1, toWorkspace: 2, screen: screen)
        engine.removeWindowMembershipOnly(w2, fromWorkspace: 1)
        engine.prepareTileLayout([w1, w3], onWorkspace: 1, screen: screen)
        return (w1, w2, w3)
    }

    func testTheWindowGoesBackToItsSlotAndRatios() {
        let (_, w2, _) = sendMiddleWindowAway()
        XCTAssertEqual(ids(1), [1, 3])

        XCTAssertEqual(engine.dedicatedReturnWorkspace(for: 2, currentWorkspace: 2), 1)
        XCTAssertTrue(engine.restoreDedicatedReturn(w2, screen: screen))

        XCTAssertEqual(ids(1), [1, 2, 3])
        let root = engine.existingTree(forWorkspace: 1, screen: screen)!.root
        XCTAssertEqual(root.splitRatio, 0.4, accuracy: 0.001)
        XCTAssertEqual(root.right?.splitRatio ?? 0, 0.3, accuracy: 0.001)
        XCTAssertEqual(root.right?.left?.window?.windowID, 2, "2 is back above 3")
        XCTAssertNil(engine.dedicatedReturnWorkspace(for: 2, currentWorkspace: 2), "the record is spent")
    }

    func testAChangedSourceFallsBackToAnOrdinaryMove() {
        let (w1, w2, w3) = sendMiddleWindowAway()
        engine.prepareTileLayout([w1, w3, makeWindow(id: 4)], onWorkspace: 1, screen: screen)

        XCTAssertFalse(engine.restoreDedicatedReturn(w2, screen: screen))
        XCTAssertEqual(Set(ids(1) ?? []), [1, 3, 4], "the live tree is left alone")
    }

    func testAWindowThatMovedElsewhereHasNoWayBack() {
        _ = sendMiddleWindowAway()
        XCTAssertNil(engine.dedicatedReturnWorkspace(for: 2, currentWorkspace: 5))
        XCTAssertNil(engine.dedicatedReturnWorkspace(for: 2, currentWorkspace: 2),
                     "a mismatch drops the record")
    }

    func testAForgottenWindowHasNoWayBack() {
        _ = sendMiddleWindowAway()
        engine.forgetAdmittedIdentity(windowID: 2)
        XCTAssertNil(engine.dedicatedReturnWorkspace(for: 2, currentWorkspace: 2))
    }

    func testAFloaterKnowsWhereItCameFromButHasNoSlot() {
        let w1 = makeWindow(id: 1), floater = makeWindow(id: 9)
        engine.prepareTileLayout([w1], onWorkspace: 1, screen: screen)

        engine.rememberDedicatedReturn(floater, fromWorkspace: 1, toWorkspace: 2, screen: screen)

        XCTAssertEqual(engine.dedicatedReturnWorkspace(for: 9, currentWorkspace: 2), 1)
        XCTAssertFalse(engine.restoreDedicatedReturn(floater, screen: screen),
                       "no slot to restore: the caller makes an ordinary move")
    }
}
