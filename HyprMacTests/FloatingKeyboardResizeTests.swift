import XCTest
import Cocoa
@testable import HyprMac

// Hypr+Ctrl+Shift+arrows on a floating window size the window itself:
// → and ↓ grow, ← and ↑ shrink, by 5% of the usable area, around the
// window's center, keeping the window on screen.

final class FloatingKeyboardResizeTests: XCTestCase {

    // the usable area of a 2560x1440 monitor under a 30pt menu bar and a Dock
    private let usable = CGRect(x: 0, y: 30, width: 2560, height: 1338)
    private let floater = CGRect(x: 512, y: 297, width: 1536, height: 803)

    private func resized(_ frame: CGRect, _ direction: Direction) -> CGRect {
        FloatingWindowController.keyboardResizedFrame(frame, direction: direction, in: usable)
    }

    func testRightAndDownGrowAroundTheCenter() {
        XCTAssertEqual(resized(floater, .right), CGRect(x: 448, y: 297, width: 1664, height: 803))
        XCTAssertEqual(resized(floater, .down), CGRect(x: 512, y: 263.5, width: 1536, height: 870))
    }

    func testLeftAndUpShrinkAroundTheCenter() {
        XCTAssertEqual(resized(floater, .left), CGRect(x: 576, y: 297, width: 1408, height: 803))
        XCTAssertEqual(resized(floater, .up), CGRect(x: 512, y: 330.5, width: 1536, height: 736))
    }

    func testTheCenterStaysPutAwayFromTheEdges() {
        var frame = floater
        for direction in [Direction.right, .down, .left, .left, .up, .up] {
            frame = resized(frame, direction)
            XCTAssertEqual(frame.midX, floater.midX, accuracy: 1)
            XCTAssertEqual(frame.midY, floater.midY, accuracy: 1)
        }
    }

    func testGrowingAtTheScreenEdgeMovesTheWindowBackInside() {
        let atRightEdge = CGRect(x: 1024, y: 297, width: 1536, height: 803)
        let grown = resized(atRightEdge, .right)
        XCTAssertEqual(grown.width, 1664)
        XCTAssertEqual(grown.maxX, usable.maxX)
        XCTAssertTrue(usable.contains(grown))
    }

    func testNeverGrowsPastTheUsableArea() {
        var frame = floater
        for _ in 0..<40 { frame = resized(frame, .right) }
        for _ in 0..<40 { frame = resized(frame, .down) }
        XCTAssertEqual(frame, usable)
    }

    func testNeverShrinksBelowTheFloor() {
        var frame = floater
        for _ in 0..<40 { frame = resized(frame, .left) }
        for _ in 0..<40 { frame = resized(frame, .up) }
        XCTAssertEqual(frame.size, CGSize(width: TilingConfig.floatingResizeMinDimension,
                                          height: TilingConfig.floatingResizeMinDimension))
        XCTAssertEqual(frame.midX, floater.midX, accuracy: 1)
        XCTAssertEqual(frame.midY, floater.midY, accuracy: 1)
    }

    func testAWindowAlreadyBelowTheFloorDoesNotGrowOnAShrink() {
        let small = CGRect(x: 100, y: 100, width: 150, height: 120)
        XCTAssertEqual(resized(small, .left), small)
        XCTAssertEqual(resized(small, .up), small)
    }
}
