import Foundation
import SwiftUI

enum BoardGeometry {
    /// Width / height of a large widget on iPhone (≈364×382). The board is
    /// pinned to this everywhere, so what you draw is what the widget shows.
    static let aspect: CGFloat = 0.95

    /// Chalk widths as a *fraction of board width*, not points. An iPad board
    /// is twice the size of an iPhone one; a fixed point width would look like
    /// a hairline there and a marker here.
    static let thinChalk: Double = 0.006
    static let mediumChalk: Double = 0.013
    static let thickChalk: Double = 0.026
    static let eraser: Double = 0.070

    /// The ink is rasterised at 3× the board's point size for the widget.
    static let renderScale: CGFloat = 3
}

struct BulletItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }

    var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The written half of the board. The drawn half lives beside it as PencilKit
/// data plus a rendered PNG — see `BoardFile`.
struct Board: Codable, Equatable {
    var bullets: [BulletItem] = []
    /// Whether the ink file holds anything, so the app and the widget can show
    /// the empty-board hint without decoding an image to find out.
    var hasInk: Bool = false
    /// Point width of the canvas the ink was drawn on, used to rescale the
    /// drawing when the same board is opened on a differently sized screen.
    var canvasWidth: Double = 0
    var updatedAt: Date = Date()

    static let empty = Board(bullets: [], hasInk: false, canvasWidth: 0, updatedAt: .distantPast)

    var isEmpty: Bool { bullets.allSatisfy(\.isBlank) && !hasInk }

    mutating func touch() { updatedAt = Date() }

    mutating func pruneBlankBullets() {
        bullets.removeAll(where: \.isBlank)
    }

    /// Shown in the widget gallery.
    static var preview: Board {
        Board(
            bullets: [
                BulletItem(text: "Milk, eggs, coffee"),
                BulletItem(text: "Call the vet at 4"),
                BulletItem(text: "Ellie — soccer kit")
            ],
            hasInk: false,
            canvasWidth: 0,
            updatedAt: Date()
        )
    }
}
