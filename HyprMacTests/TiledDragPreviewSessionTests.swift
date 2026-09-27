import XCTest
@testable import HyprMac

final class TiledDragPreviewSessionTests: XCTestCase {
    private final class Harness {
        var time: TimeInterval = 100
        var shows: [CGRect] = []
        var hides = 0
        var asked: [CGPoint] = []
        var held: [(delay: TimeInterval, work: () -> Void)] = []
        lazy var session = TiledDragPreviewSession(
            presenter: .init(show: { [unowned self] in shows.append($0) },
                             hide: { [unowned self] in hides += 1 }),
            now: { [unowned self] in time },
            schedule: { [unowned self] delay, work in held.append((delay, work)) })

        /// left of x=500 lands in `left`, right of it in `right`, past 900 nowhere
        func begin(left: CGRect = Harness.left, right: CGRect = Harness.right) {
            session.begin { [unowned self] point in
                asked.append(point)
                if point.x > 900 { return nil }
                return point.x < 500 ? left : right
            }
        }

        func runHeld() {
            let work = held
            held.removeAll()
            work.forEach { $0.work() }
        }

        static let left = CGRect(x: 0, y: 0, width: 400, height: 300)
        static let right = CGRect(x: 600, y: 0, width: 400, height: 300)
    }

    func testShowsOnlyWhenTheLandingRectChanges() {
        let harness = Harness()
        harness.begin()

        harness.session.move(to: CGPoint(x: 10, y: 10))
        harness.time += 1
        harness.session.move(to: CGPoint(x: 20, y: 10))
        harness.time += 1
        harness.session.move(to: CGPoint(x: 700, y: 10))

        XCTAssertEqual(harness.shows, [Harness.left, Harness.right])
        XCTAssertEqual(harness.asked.count, 3)
        XCTAssertEqual(harness.hides, 0)
    }

    func testNowhereToLandHidesUntilThereIsAgain() {
        let harness = Harness()
        harness.begin()
        harness.session.move(to: CGPoint(x: 10, y: 10))
        harness.time += 1
        harness.session.move(to: CGPoint(x: 950, y: 10))
        harness.time += 1
        harness.session.move(to: CGPoint(x: 960, y: 10))

        XCTAssertEqual(harness.hides, 1, "a restore shows nothing, once")
        XCTAssertNil(harness.session.shown)
        harness.time += 1
        harness.session.move(to: CGPoint(x: 10, y: 10))
        XCTAssertEqual(harness.shows, [Harness.left, Harness.left])
    }

    func testThrottlesToOneAnswerPerFrameAndKeepsTheLastMove() {
        let harness = Harness()
        harness.begin()
        harness.session.move(to: CGPoint(x: 10, y: 10))
        harness.time += 0.004
        harness.session.move(to: CGPoint(x: 600, y: 10))
        harness.time += 0.004
        harness.session.move(to: CGPoint(x: 700, y: 10))

        XCTAssertEqual(harness.asked, [CGPoint(x: 10, y: 10)], "held inside the frame")
        XCTAssertEqual(harness.held.count, 1, "one held update, however many moves")
        XCTAssertEqual(harness.held.first?.delay ?? 0, TiledDragPreviewSession.interval - 0.004,
                       accuracy: 1e-9)

        harness.time += 0.01
        harness.runHeld()
        XCTAssertEqual(harness.asked.last, CGPoint(x: 700, y: 10), "the last move wins")
        XCTAssertEqual(harness.shows, [Harness.left, Harness.right])
    }

    func testEndHidesAndDropsHeldWork() {
        let harness = Harness()
        harness.begin()
        harness.session.move(to: CGPoint(x: 10, y: 10))
        harness.time += 0.004
        harness.session.move(to: CGPoint(x: 700, y: 10))

        harness.session.end()
        XCTAssertEqual(harness.hides, 1)
        XCTAssertFalse(harness.session.isActive)
        harness.time += 1
        harness.runHeld()
        harness.session.move(to: CGPoint(x: 700, y: 10))
        harness.session.refresh()
        XCTAssertEqual(harness.shows, [Harness.left], "nothing after the drag ends")
        harness.session.end()
        XCTAssertEqual(harness.hides, 1, "ending twice hides once")
    }

    func testRefreshAsksAgainAtTheLastPoint() {
        let harness = Harness()
        var swap = false
        let tile = CGRect(x: 0, y: 0, width: 800, height: 600)
        harness.session.begin { point in
            swap ? tile : CGRect(x: point.x, y: 0, width: 400, height: 600)
        }
        harness.session.move(to: CGPoint(x: 0, y: 10))
        swap = true
        harness.time += 1
        harness.session.refresh()

        XCTAssertEqual(harness.shows, [CGRect(x: 0, y: 0, width: 400, height: 600), tile])
    }

    func testBeginningAgainEndsThePreviousPreview() {
        let harness = Harness()
        harness.begin()
        harness.session.move(to: CGPoint(x: 10, y: 10))
        harness.begin()
        XCTAssertEqual(harness.hides, 1)
        XCTAssertNil(harness.session.shown)
        harness.time += 1
        harness.session.refresh()
        XCTAssertEqual(harness.shows, [Harness.left], "a new drag starts with no point")
    }
}
