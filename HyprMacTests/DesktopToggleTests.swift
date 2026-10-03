import XCTest
import Cocoa
@testable import HyprMac

// Turning HyprMac off for one native desktop, and where a new window lands.

final class DesktopToggleTests: XCTestCase {

    // MARK: - the off switch

    func testOnlyWindowlessActionsRunOnADisabledDesktop() {
        for action: Action in [.showKeybinds, .launchApp(bundleID: "com.apple.Terminal"),
                               .runCommand(label: "", command: "/usr/bin/true"), .focusMenuBar,
                               .toggleTiling, .toggleDesktopTiling] {
            XCTAssertTrue(WindowManager.runsOnDisabledDesktop(action), "\(action)")
        }
        for action: Action in [.focusDirection(.left), .swapDirection(.right), .switchWorkspace(2),
                               .moveToWorkspace(3), .toggleFloating, .flipWorkspace,
                               .moveToNextEmptyWorkspace, .retileAll, .showWorkspaceOverview] {
            XCTAssertFalse(WindowManager.runsOnDisabledDesktop(action), "\(action)")
        }
    }

    func testWireFormatRoundTrips() throws {
        let data = try JSONEncoder().encode(Action.toggleDesktopTiling)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"toggleDesktopTiling":{}}"#)
        XCTAssertEqual(try JSONDecoder().decode(Action.self, from: data), .toggleDesktopTiling)
    }

    func testDefaultIsHyprShiftP() {
        let binds = Keybind.defaults.filter { $0.action == .toggleDesktopTiling }
        XCTAssertEqual(binds.count, 1)
        XCTAssertEqual(binds.first?.keyCode, 35) // kVK_ANSI_P
        XCTAssertEqual(binds.first?.modifiers, [.hypr, .shift])
        let chord = binds.first.map { "\($0.modifiers.rawValue)-\($0.keyCode)" }
        XCTAssertEqual(Keybind.defaults.filter { "\($0.modifiers.rawValue)-\($0.keyCode)" == chord }.count, 1)
    }

    func testAMonitorConfigWithoutDisabledDesktopsStillLoads() throws {
        let old = #"{"maxSplitsPerMonitor":{"Display A":4},"disabledMonitors":["Display B"]}"#
        let config = try JSONDecoder().decode(SavedMonitorConfig.self, from: Data(old.utf8))
        XCTAssertNil(config.disabledDesktops)
        XCTAssertEqual(config.disabledMonitors, ["Display B"])
    }

    func testDisabledDesktopsRoundTrip() throws {
        let config = SavedMonitorConfig(maxSplitsPerMonitor: nil, disabledMonitors: nil,
                                        disabledDesktops: ["5DFFD352-D6E3-1ADD-616A-B0ECC5985E3E"])
        let decoded = try JSONDecoder().decode(SavedMonitorConfig.self,
                                               from: try JSONEncoder().encode(config))
        XCTAssertEqual(decoded.disabledDesktops, ["5DFFD352-D6E3-1ADD-616A-B0ECC5985E3E"])
    }

    // MARK: - the window a new one was opened from

    func testFocusHistoryKeepsTheWindowBeforeTheCurrentOne() {
        let focus = FocusStateController(focusBorder: FocusBorder())
        focus.recordFocus(10, reason: "test")
        focus.recordFocus(20, reason: "test")
        XCTAssertEqual(focus.lastFocusedID, 20)
        XCTAssertEqual(focus.previousFocusedID, 10)

        // clearing focus keeps the last real window as the previous one
        focus.recordFocus(0, reason: "test")
        XCTAssertEqual(focus.previousFocusedID, 20)
        focus.recordFocus(30, reason: "test")
        XCTAssertEqual(focus.previousFocusedID, 20, "0 is not a window to remember")
    }
}
