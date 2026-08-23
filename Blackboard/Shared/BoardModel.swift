import Foundation
import SwiftUI

/// Everything on the board is stored in a unit square (0...1 on both axes) so
/// the app canvas and the widget — which are different pixel sizes — render
/// identically. The board is pinned to `BoardGeometry.aspect` in the app, so
/// what you draw is what the widget shows.
enum BoardGeometry {
    /// Width / height of a large widget on iPhone (≈364×382).
    static let aspect: CGFloat = 0.95

    /// Stroke widths, as a fraction of board width.
    static let thinChalk: Double = 0.008
    static let mediumChalk: Double = 0.016
    static let thickChalk: Double = 0.030
    static let eraser: Double = 0.075

    /// Points closer together than this (normalized) are dropped while drawing.
    /// Keeps the saved board small enough to decode cheaply in the widget.
    static let minPointSpacing: Double = 0.004

    /// Hard ceiling so a marathon doodling session can't bloat the payload the
    /// widget has to decode on every refresh.
    static let maxStrokes = 600
}

struct BoardPoint: Codable, Hashable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }

    func distance(to other: BoardPoint) -> Double {
        let dx = x - other.x, dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

enum ChalkColor: String, Codable, CaseIterable, Identifiable {
    case white, yellow, pink, blue, mint

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white:  return Color(red: 0.96, green: 0.96, blue: 0.93)
        case .yellow: return Color(red: 0.98, green: 0.87, blue: 0.45)
        case .pink:   return Color(red: 0.97, green: 0.65, blue: 0.72)
        case .blue:   return Color(red: 0.62, green: 0.82, blue: 0.95)
        case .mint:   return Color(red: 0.66, green: 0.92, blue: 0.75)
        }
    }

    var displayName: String {
        switch self {
        case .white:  return "White chalk"
        case .yellow: return "Yellow chalk"
        case .pink:   return "Pink chalk"
        case .blue:   return "Blue chalk"
        case .mint:   return "Mint chalk"
        }
    }
}

struct Stroke: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var color: ChalkColor = .white
    /// Fraction of board width.
    var width: Double = BoardGeometry.mediumChalk
    var isEraser: Bool = false
    var points: [BoardPoint] = []

    /// Appends a point unless it is close enough to the last one to be noise.
    mutating func extend(to point: BoardPoint) {
        guard let last = points.last else {
            points.append(point)
            return
        }
        guard last.distance(to: point) >= BoardGeometry.minPointSpacing else { return }
        points.append(point)
    }
}

struct BulletItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

struct Board: Codable, Equatable {
    var strokes: [Stroke] = []
    var bullets: [BulletItem] = []
    var updatedAt: Date = Date()

    static let empty = Board(strokes: [], bullets: [], updatedAt: .distantPast)

    var isEmpty: Bool { strokes.isEmpty && bullets.isEmpty }

    mutating func touch() { updatedAt = Date() }

    mutating func append(_ stroke: Stroke) {
        guard !stroke.points.isEmpty else { return }
        strokes.append(stroke)
        if strokes.count > BoardGeometry.maxStrokes {
            strokes.removeFirst(strokes.count - BoardGeometry.maxStrokes)
        }
        touch()
    }

    /// A board sample used for the widget gallery preview.
    static var preview: Board {
        var board = Board()
        board.bullets = [
            BulletItem(text: "Milk, eggs, coffee"),
            BulletItem(text: "Call the vet at 4"),
            BulletItem(text: "Ellie — soccer kit")
        ]
        // A loose chalk smiley so the gallery entry reads as a blackboard.
        var arc = Stroke(color: .yellow, width: BoardGeometry.mediumChalk)
        for step in 0...24 {
            let t = Double(step) / 24
            let angle = .pi * 0.15 + t * .pi * 0.7
            arc.points.append(BoardPoint(x: 0.5 + cos(angle) * -0.22, y: 0.72 + sin(angle) * 0.16))
        }
        board.strokes = [arc]
        board.updatedAt = Date()
        return board
    }
}
