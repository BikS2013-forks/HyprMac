import XCTest
import Cocoa
@testable import HyprMac

// A tiled window toggled to floating lands centered on its screen at 60% of
// the usable width and height.

final class FloatingToggleFrameTests: XCTestCase {

    // the usable area of a 2560x1440 monitor under a 30pt menu bar and a Dock
    private let monitor = CGRect(x: 0, y: 30, width: 2560, height: 1338)

    func testSixtyPercentOfEachDimension() {
        let frame = FloatingWindowController.toggledFloatingFrame(in: monitor)
        XCTAssertEqual(frame.width, 1536)
        XCTAssertEqual(frame.height, 803)
    }

    func testCenteredOnTheUsableArea() {
        let frame = FloatingWindowController.toggledFloatingFrame(in: monitor)
        XCTAssertEqual(frame.midX, monitor.midX, accuracy: 1)
        XCTAssertEqual(frame.midY, monitor.midY, accuracy: 1)
        XCTAssertTrue(monitor.contains(frame))
    }

    func testFollowsAScreenThatIsNotAtTheOrigin() {
        let laptop = CGRect(x: 2560, y: 491, width: 1512, height: 949)
        let frame = FloatingWindowController.toggledFloatingFrame(in: laptop)
        XCTAssertEqual(frame.width, 907)
        XCTAssertEqual(frame.height, 569)
        XCTAssertEqual(frame.midX, laptop.midX, accuracy: 1)
        XCTAssertEqual(frame.midY, laptop.midY, accuracy: 1)
    }
}
