// The live drop preview for one tiled drag: asks where the window would
// land as the pointer moves, at most once per frame interval, and tells the
// presenter only when that changes.

import CoreGraphics
import Foundation

final class TiledDragPreviewSession {
    typealias Frame = (CGPoint) -> CGRect?
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> Void

    struct Presenter {
        let show: (CGRect) -> Void
        let hide: () -> Void
    }

    /// about 60 updates a second, whatever rate the drag events come at
    static let interval: TimeInterval = 1.0 / 60

    private let presenter: Presenter
    private let now: () -> TimeInterval
    private let schedule: Schedule
    private var frame: Frame?
    private var epoch: UInt64 = 0
    private var point: CGPoint?
    private var lastUpdate: TimeInterval = -.infinity
    private var trailingScheduled = false
    private(set) var shown: CGRect?

    var isActive: Bool { frame != nil }

    init(presenter: Presenter,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         schedule: @escaping Schedule = { delay, work in
             DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
         }) {
        self.presenter = presenter
        self.now = now
        self.schedule = schedule
    }

    /// Start a drag's preview. `frame` answers where the window would land
    /// for a pointer, nil where the drop would restore.
    func begin(frame: @escaping Frame) {
        end()
        epoch &+= 1
        self.frame = frame
        lastUpdate = -.infinity
    }

    /// The pointer moved. A move inside the interval is held and applied
    /// once the interval is up, so the last position always shows.
    func move(to point: CGPoint) {
        guard isActive else { return }
        self.point = point
        update()
    }

    /// Ask again at the last point: a modifier changed what a drop would do.
    func refresh() {
        guard isActive else { return }
        update()
    }

    /// Hide the preview and drop any held move. Safe to call at any time.
    func end() {
        epoch &+= 1
        frame = nil
        point = nil
        trailingScheduled = false
        if shown != nil {
            shown = nil
            presenter.hide()
        }
    }

    private func update() {
        let elapsed = now() - lastUpdate
        guard elapsed >= Self.interval else {
            guard !trailingScheduled else { return }
            trailingScheduled = true
            let session = epoch
            schedule(Self.interval - elapsed) { [weak self] in
                guard let self, self.epoch == session else { return }
                self.trailingScheduled = false
                self.update()
            }
            return
        }
        guard let frame, let point else { return }
        lastUpdate = now()
        let rect = frame(point)
        guard rect != shown else { return }
        shown = rect
        if let rect {
            presenter.show(rect)
        } else {
            presenter.hide()
        }
    }
}
