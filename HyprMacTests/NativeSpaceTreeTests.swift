import XCTest
import Cocoa
@testable import HyprMac

// Switching native Spaces (macOS desktops) takes one Space's windows off the
// on-screen list and brings another's back. The engine parks each Space's
// trees so the returning windows keep their slots and user-set ratios
// instead of being re-inserted with defaults.

final class NativeSpaceTreeTests: XCTestCase {

    private var displayManager: DisplayManager!
    private var engine: TilingEngine!
    private var screen: NSScreen!

    private let spaceA: UInt64 = 101
    private let spaceB: UInt64 = 202

    override func setUpWithError() throws {
        displayManager = DisplayManager()
        engine = TilingEngine(displayManager: displayManager)
        guard let main = NSScreen.main ?? NSScreen.screens.first else {
            throw XCTSkip("no NSScreen available, test requires a display")
        }
        screen = main
    }

    private func tree() -> BSPTree? {
        engine.existingTree(forWorkspace: 1, screen: screen)
    }

    @discardableResult
    private func sync(_ space: UInt64, existing: Set<UInt64>? = nil) -> Bool {
        engine.syncNativeSpaces([.init(screen: screen, space: space)],
                                existingSpaces: existing ?? [spaceA, spaceB])
    }

    /// Tile two windows on Space A with a user-set 0.7 split.
    private func tileSpaceA() -> [HyprWindow] {
        sync(spaceA)
        let windows = [makeWindow(id: 1), makeWindow(id: 2)]
        engine.prepareTileLayout(windows, onWorkspace: 1, screen: screen)
        tree()?.root.splitRatio = 0.7
        tree()?.root.userSetRatio = true
        return windows
    }

    func testFirstReadingOnlyRecordsTheSpace() {
        let windows = [makeWindow(id: 1), makeWindow(id: 2)]
        engine.prepareTileLayout(windows, onWorkspace: 1, screen: screen)

        XCTAssertFalse(sync(spaceA))
        XCTAssertEqual(tree()?.allWindows.map(\.windowID), [1, 2])
    }

    func testSameSpaceIsANoOp() {
        _ = tileSpaceA()
        XCTAssertFalse(sync(spaceA))
        XCTAssertEqual(tree()?.root.splitRatio ?? 0, 0.7, accuracy: 0.001)
    }

    func testSwitchingAwayParksTheTree() {
        _ = tileSpaceA()

        XCTAssertTrue(sync(spaceB))

        XCTAssertNil(tree(), "Space B starts without Space A's tree")
        XCTAssertEqual(engine.parkedNativeSpaceWindowIDs(forWorkspace: 1, screen: screen, space: spaceA),
                       [1, 2])
    }

    func testRoundTripKeepsUserRatio() {
        let spaceAWindows = tileSpaceA()

        sync(spaceB)
        // Space B's own windows tile and get their own ratio
        let spaceBWindows = [makeWindow(id: 3), makeWindow(id: 4)]
        engine.prepareTileLayout(spaceBWindows, onWorkspace: 1, screen: screen)
        tree()?.root.splitRatio = 0.3
        tree()?.root.userSetRatio = true

        sync(spaceA)
        engine.prepareTileLayout(spaceAWindows, onWorkspace: 1, screen: screen)

        XCTAssertEqual(tree()?.allWindows.map(\.windowID), [1, 2])
        XCTAssertEqual(tree()?.root.splitRatio ?? 0, 0.7, accuracy: 0.001)
        XCTAssertEqual(tree()?.root.userSetRatio, true)
        XCTAssertEqual(engine.parkedNativeSpaceWindowIDs(forWorkspace: 1, screen: screen, space: spaceB),
                       [3, 4])

        sync(spaceB)
        engine.prepareTileLayout(spaceBWindows, onWorkspace: 1, screen: screen)
        XCTAssertEqual(tree()?.root.splitRatio ?? 0, 0.3, accuracy: 0.001)
    }

    func testGonePathCannotReachAParkedTree() {
        _ = tileSpaceA()
        sync(spaceB)

        // the next poll on Space B sees 1 and 2 as gone
        engine.removeWindowID(1)
        engine.removeWindowID(2)

        sync(spaceA)
        XCTAssertEqual(tree()?.allWindows.map(\.windowID), [1, 2])
        XCTAssertEqual(tree()?.root.splitRatio ?? 0, 0.7, accuracy: 0.001)
    }

    func testDeletedSpaceDropsItsParkedTree() {
        _ = tileSpaceA()
        sync(spaceB)

        sync(spaceB, existing: [spaceB])

        XCTAssertNil(engine.parkedNativeSpaceWindowIDs(forWorkspace: 1, screen: screen, space: spaceA))
    }

    // screenParametersChanged also fires for a Dock or menu bar change with
    // the same monitors in place. a live check lost every parked tree to one.
    func testDisplayChangeWithTheSameScreensKeepsParkedTrees() {
        let spaceAWindows = tileSpaceA()
        sync(spaceB)

        engine.handleDisplayChange(currentScreens: [screen], homeScreenForWorkspace: { _ in self.screen })

        XCTAssertEqual(engine.parkedNativeSpaceWindowIDs(forWorkspace: 1, screen: screen, space: spaceA),
                       [1, 2])
        XCTAssertTrue(sync(spaceA), "the screen's Space is still known, so the return swaps")
        engine.prepareTileLayout(spaceAWindows, onWorkspace: 1, screen: screen)
        XCTAssertEqual(tree()?.root.splitRatio ?? 0, 0.7, accuracy: 0.001)
    }

    func testDisplayChangeDropsParkedTreesOfAScreenThatLeft() {
        _ = tileSpaceA()
        sync(spaceB)

        engine.handleDisplayChange(currentScreens: [], homeScreenForWorkspace: { _ in nil })

        XCTAssertNil(engine.parkedNativeSpaceWindowIDs(forWorkspace: 1, screen: screen, space: spaceA))
        XCTAssertFalse(sync(spaceA), "the first reading after the screen returns only records")
    }

    // MARK: - snapshot filter

    // mid-switch the on-screen list holds both desktops' windows. only the
    // window server's Space membership tells them apart.
    func testWindowsOnlyOnInactiveSpacesAreLeftOut() {
        let membership: [CGWindowID: Set<UInt64>] = [
            1: [spaceA],          // this desktop
            2: [spaceB],          // the other desktop, visible mid-animation
            3: [],                // the window server does not say
            4: [spaceA, spaceB],  // on every desktop
            5: [303],             // the active Space of another display
        ]
        let split = SpaceManager.classifyWindows([1, 2, 3, 4, 5], activeSpaces: [spaceA, 303],
                                                 disabledSpaces: [],
                                                 spacesForWindow: { membership[$0] ?? [] })
        XCTAssertEqual(split.offSpace, [2])
        XCTAssertEqual(split.onDisabled, [])
    }

    // a desktop the user turned HyprMac off for: its windows are set apart
    // from windows on other desktops, so the caller can keep the ones it
    // parked there
    func testWindowsOnADisabledDesktopAreSetApart() {
        let membership: [CGWindowID: Set<UInt64>] = [
            1: [spaceA],          // the disabled desktop
            2: [303],             // the other display's enabled desktop
            3: [spaceA, 303],     // on every desktop: an enabled one still shows it
            4: [spaceB],          // an inactive desktop
        ]
        let split = SpaceManager.classifyWindows([1, 2, 3, 4], activeSpaces: [spaceA, 303],
                                                 disabledSpaces: [spaceA],
                                                 spacesForWindow: { membership[$0] ?? [] })
        XCTAssertEqual(split.onDisabled, [1])
        XCTAssertEqual(split.offSpace, [4])
    }
}
