import CoreGraphics

struct TiledDragTarget: Equatable {
    let windowID: CGWindowID
    let edge: BSPTargetEdge
}

struct TiledDragTargetResolver {
    static func resolve(pointer: CGPoint, draggedID: CGWindowID,
                        intendedSlots: [CGWindowID: CGRect]) -> TiledDragTarget? {
        guard pointer.x.isFinite, pointer.y.isFinite else { return nil }
        let hits = intendedSlots.filter { windowID, frame in
            guard windowID != draggedID,
                  frame.origin.x.isFinite, frame.origin.y.isFinite,
                  frame.size.width.isFinite, frame.size.height.isFinite,
                  frame.size.width > 0, frame.size.height > 0 else { return false }
            return pointer.x >= frame.minX && pointer.x <= frame.maxX
                && pointer.y >= frame.minY && pointer.y <= frame.maxY
        }
        guard hits.count == 1, let (windowID, frame) = hits.first else { return nil }
        return TiledDragTarget(windowID: windowID, edge: edge(of: pointer, in: frame))
    }

    /// The tile nearest `pointer`, for a release on another monitor. A
    /// pointer inside a tile picks it; one in a gap or the padding picks the
    /// closest tile, lower id on a tie. The edge uses the same normalized
    /// rule, measured from the pointer clamped into that tile.
    static func nearest(pointer: CGPoint, slots: [CGWindowID: CGRect]) -> TiledDragTarget? {
        guard pointer.x.isFinite, pointer.y.isFinite else { return nil }
        let ranked = slots.filter { _, frame in
            frame.origin.x.isFinite && frame.origin.y.isFinite
                && frame.size.width.isFinite && frame.size.height.isFinite
                && frame.size.width > 0 && frame.size.height > 0
        }.map { windowID, frame in
            let dx = max(frame.minX - pointer.x, 0, pointer.x - frame.maxX)
            let dy = max(frame.minY - pointer.y, 0, pointer.y - frame.maxY)
            return (windowID: windowID, frame: frame, distance: (dx * dx + dy * dy).squareRoot())
        }
        guard let best = ranked.min(by: {
            ($0.distance, $0.windowID) < ($1.distance, $1.windowID)
        }) else { return nil }
        let clamped = CGPoint(x: min(max(pointer.x, best.frame.minX), best.frame.maxX),
                              y: min(max(pointer.y, best.frame.minY), best.frame.maxY))
        return TiledDragTarget(windowID: best.windowID, edge: edge(of: clamped, in: best.frame))
    }

    /// Nearest normalized edge of `frame` to `pointer`. Ties go left, right,
    /// top, bottom.
    private static func edge(of pointer: CGPoint, in frame: CGRect) -> BSPTargetEdge {
        let distances: [(BSPTargetEdge, CGFloat)] = [
            (.left, (pointer.x - frame.minX) / frame.width),
            (.right, (frame.maxX - pointer.x) / frame.width),
            (.top, (pointer.y - frame.minY) / frame.height),
            (.bottom, (frame.maxY - pointer.y) / frame.height)
        ]
        return distances.dropFirst().reduce(distances[0]) { nearest, candidate in
            candidate.1 < nearest.1 ? candidate : nearest
        }.0
    }
}
