import XCTest
import Cocoa
@testable import HyprMac

// Flip workspace mirrors the whole layout left↔right: side-by-side splits
// swap their children and take 1 - ratio, top/bottom splits stay, and every
// side keeps its width.

final class FlipWorkspaceTests: XCTestCase {

    private func frames(_ tree: BSPTree) -> [CGWindowID: CGRect] {
        Dictionary(uniqueKeysWithValues: tree.layout(in: defaultRect, gap: defaultGap, padding: defaultPadding)
            .map { ($0.0.windowID, $0.1) })
    }

    private func mirror(_ tree: BSPTree) -> Bool {
        tree.mirrorHorizontally(in: defaultRect, gap: defaultGap, padding: defaultPadding)
    }

    /// Two windows side by side with a 0.7 split.
    private func twoUp() -> BSPTree {
        let tree = BSPTree()
        tree.insert(makeWindow(id: 1))
        tree.insert(makeWindow(id: 2))
        tree.root.splitRatio = 0.7
        tree.root.userSetRatio = true
        return tree
    }

    func testTwoWindowsTradeSidesAndKeepTheirWidths() {
        let tree = twoUp()
        let before = frames(tree)

        XCTAssertTrue(mirror(tree))

        let after = frames(tree)
        XCTAssertEqual(tree.root.left?.window?.windowID, 2)
        XCTAssertEqual(tree.root.right?.window?.windowID, 1)
        XCTAssertEqual(tree.root.splitRatio, 0.3, accuracy: 0.0001)
        XCTAssertTrue(tree.root.userSetRatio, "a user ratio stays a user ratio")
        XCTAssertEqual(after[1]!.width, before[1]!.width, accuracy: 0.5)
        XCTAssertEqual(after[2]!.width, before[2]!.width, accuracy: 0.5)
        XCTAssertGreaterThan(after[1]!.minX, after[2]!.minX, "window 1 is on the right now")
    }

    // dwindle: 1 | (2 / 3). the stack on the right moves left as a group,
    // still 2 over 3.
    func testAStackedSideMovesAcrossAsAGroup() {
        let tree = BSPTree()
        for id in 1...3 { tree.insert(makeWindow(id: CGWindowID(id))) }
        tree.root.splitRatio = 0.6
        let before = frames(tree)

        XCTAssertTrue(mirror(tree))

        let after = frames(tree)
        for id: CGWindowID in 1...3 {
            XCTAssertEqual(after[id]!.size.width, before[id]!.size.width, accuracy: 0.5)
            XCTAssertEqual(after[id]!.size.height, before[id]!.size.height, accuracy: 0.5)
            XCTAssertEqual(after[id]!.minY, before[id]!.minY, accuracy: 0.5, "rows do not move")
        }
        XCTAssertLessThan(after[2]!.minX, after[1]!.minX)
        XCTAssertEqual(after[2]!.minX, after[3]!.minX, accuracy: 0.5)
        XCTAssertLessThan(after[2]!.minY, after[3]!.minY, "2 stays above 3")
    }

    func testFlippingTwiceGivesBackTheLayout() {
        let tree = BSPTree()
        for id in 1...4 { tree.insert(makeWindow(id: CGWindowID(id))) }
        tree.root.splitRatio = 0.65
        let before = frames(tree)

        XCTAssertTrue(mirror(tree))
        XCTAssertTrue(mirror(tree))

        let after = frames(tree)
        for (id, frame) in before {
            XCTAssertEqual(after[id]!.minX, frame.minX, accuracy: 0.5)
            XCTAssertEqual(after[id]!.minY, frame.minY, accuracy: 0.5)
            XCTAssertEqual(after[id]!.width, frame.width, accuracy: 0.5)
            XCTAssertEqual(after[id]!.height, frame.height, accuracy: 0.5)
        }
    }

    func testOnlyStackedWindowsHaveNothingToFlip() {
        let tree = twoUp()
        tree.root.splitOverride = .vertical
        let before = frames(tree)

        XCTAssertFalse(mirror(tree))
        XCTAssertEqual(frames(tree), before)
    }

    func testASingleWindowHasNothingToFlip() {
        let tree = BSPTree()
        tree.insert(makeWindow(id: 1))
        XCTAssertFalse(mirror(tree))
    }

    func testTopologySnapshotUndoesTheFlip() {
        let tree = BSPTree()
        for id in 1...3 { tree.insert(makeWindow(id: CGWindowID(id))) }
        let before = frames(tree)
        let topology = tree.topologySnapshot()
        let knobs = tree.snapshot()

        mirror(tree)
        tree.restore(topology)
        tree.restore(knobs)

        XCTAssertEqual(frames(tree), before)
        XCTAssertTrue(tree.root.left?.parent === tree.root)
        XCTAssertTrue(tree.root.right?.parent === tree.root)
    }

    // MARK: - engine

    func testEngineFlipsThroughTheVerifiedRetile() throws {
        let dm = DisplayManager()
        guard let screen = dm.screens.first else { throw XCTSkip("test requires a display") }
        let engine = TilingEngine(displayManager: dm, frameSizingIOFactory: acceptingFrameSizingIOFactory())
        engine.prepareTileLayout([makeWindow(id: 1), makeWindow(id: 2)], onWorkspace: 1, screen: screen)
        let tree = try XCTUnwrap(engine.existingTree(forWorkspace: 1, screen: screen))
        tree.root.splitRatio = 0.7
        tree.root.userSetRatio = true

        XCTAssertTrue(engine.flipWorkspace(onWorkspace: 1, screen: screen))

        XCTAssertEqual(tree.root.left?.window?.windowID, 2)
        XCTAssertEqual(tree.root.splitRatio, 0.3, accuracy: 0.0001)
    }

    func testEngineRefusesAWorkspaceWithoutATree() throws {
        let dm = DisplayManager()
        guard let screen = dm.screens.first else { throw XCTSkip("test requires a display") }
        let engine = TilingEngine(displayManager: dm, frameSizingIOFactory: acceptingFrameSizingIOFactory())
        XCTAssertFalse(engine.flipWorkspace(onWorkspace: 3, screen: screen))
    }

    // MARK: - keybind

    func testWireFormatRoundTrips() throws {
        let data = try JSONEncoder().encode(Action.flipWorkspace)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"flipWorkspace":{}}"#)
        XCTAssertEqual(try JSONDecoder().decode(Action.self, from: data), .flipWorkspace)
    }

    func testDefaultIsHyprShiftJ() {
        let binds = Keybind.defaults.filter { $0.action == .flipWorkspace }
        XCTAssertEqual(binds.count, 1)
        XCTAssertEqual(binds.first?.keyCode, 38) // kVK_ANSI_J
        XCTAssertEqual(binds.first?.modifiers, [.hypr, .shift])
        let chord = binds.first.map { "\($0.modifiers.rawValue)-\($0.keyCode)" }
        XCTAssertEqual(Keybind.defaults.filter { "\($0.modifiers.rawValue)-\($0.keyCode)" == chord }.count, 1,
                       "no other default uses the chord")
    }
}
