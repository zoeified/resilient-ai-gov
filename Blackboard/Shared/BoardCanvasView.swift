import SwiftUI

/// The single renderer used by both the app and the widget. Because strokes are
/// stored in a unit square and every size is derived from the rendered width,
/// the widget shows exactly what you drew in the app.
struct BoardCanvasView: View {

    let board: Board
    /// The stroke currently under the user's finger, drawn but not yet saved.
    var liveStroke: Stroke?
    /// How many bullets fit before the list is truncated with a "+n more".
    var maxBullets: Int = 8
    /// The app paints its own slate; the widget uses `containerBackground`.
    var showsBackground: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                if showsBackground {
                    ChalkboardBackground()
                }

                BulletsLayer(bullets: board.bullets, size: size, maxBullets: maxBullets)
                    .equatable()

                CommittedStrokesLayer(strokes: board.strokes)
                    .equatable()

                LiveStrokeLayer(stroke: liveStroke)

                if board.isEmpty && liveStroke == nil {
                    EmptyBoardHint(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

// MARK: - Chalk

/// Committed strokes live in their own layer with a cheap equality check, so
/// dragging a finger repaints only the stroke under it rather than the whole
/// board on every sample.
private struct CommittedStrokesLayer: View, Equatable {
    let strokes: [Stroke]

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            for stroke in strokes {
                ChalkRenderer.draw(stroke, in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    /// Strokes are only ever appended, removed from the end, or cleared, so
    /// count plus the identity of the last one is enough to spot a change —
    /// and it avoids comparing thousands of points every frame.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.strokes.count == rhs.strokes.count
            && lhs.strokes.last?.id == rhs.strokes.last?.id
    }
}

private struct LiveStrokeLayer: View {
    let stroke: Stroke?

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            if let stroke {
                ChalkRenderer.draw(stroke, in: &context, size: size)
            }
        }
        .allowsHitTesting(false)
    }
}

enum ChalkRenderer {

    static func draw(_ stroke: Stroke, in context: inout GraphicsContext, size: CGSize) {
        let points = stroke.points.map {
            CGPoint(x: $0.x * size.width, y: $0.y * size.height)
        }
        guard let first = points.first else { return }

        let lineWidth = max(1.2, stroke.width * size.width)
        let shading: GraphicsContext.Shading = stroke.isEraser
            ? .color(ChalkTheme.eraserSmudge)
            : .color(stroke.color.color.opacity(0.88))

        // A tap with no drag is a chalk dot.
        guard points.count > 1 else {
            let dot = CGRect(
                x: first.x - lineWidth / 2,
                y: first.y - lineWidth / 2,
                width: lineWidth,
                height: lineWidth
            )
            context.fill(Circle().path(in: dot), with: shading)
            return
        }

        let path = smoothedPath(points)
        context.stroke(
            path,
            with: shading,
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        // Second, broken pass: the grain that makes chalk look like chalk.
        guard !stroke.isEraser else { return }
        context.stroke(
            path,
            with: .color(.white.opacity(0.22)),
            style: StrokeStyle(
                lineWidth: lineWidth * 0.55,
                lineCap: .round,
                lineJoin: .round,
                dash: [lineWidth * 0.5, lineWidth * 1.1],
                dashPhase: lineWidth * 0.3
            )
        )
    }

    /// Quadratic smoothing through midpoints — turns the sampled finger
    /// positions into a line that reads as handwriting rather than polygons.
    static func smoothedPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        guard points.count > 2 else {
            path.addLine(to: points[points.count - 1])
            return path
        }

        for index in 1..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let midpoint = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: midpoint, control: current)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}

// MARK: - Bullets

private struct BulletsLayer: View, Equatable {
    let bullets: [BulletItem]
    let size: CGSize
    let maxBullets: Int

    private var nonEmpty: [BulletItem] {
        bullets.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private var visible: [BulletItem] { Array(nonEmpty.prefix(maxBullets)) }
    private var overflow: Int { max(0, nonEmpty.count - maxBullets) }

    var body: some View {
        VStack(alignment: .leading, spacing: size.height * 0.016) {
            ForEach(visible) { item in
                HStack(alignment: .firstTextBaseline, spacing: size.width * 0.025) {
                    Text("•")
                        .font(ChalkTheme.chalkFont(size: size.width * 0.052))
                    Text(item.text)
                        .font(ChalkTheme.chalkFont(size: size.width * 0.052))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white.opacity(0.92))
            }

            if overflow > 0 {
                Text("+\(overflow) more")
                    .font(ChalkTheme.chalkFont(size: size.width * 0.040))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, size.width * 0.06)
        .padding(.top, size.height * 0.055)
        .frame(width: size.width, alignment: .leading)
        .allowsHitTesting(false)
    }
}

private struct EmptyBoardHint: View {
    let size: CGSize

    var body: some View {
        VStack(spacing: size.height * 0.02) {
            Image(systemName: "hand.draw")
                .font(.system(size: size.width * 0.11, weight: .light))
            Text("Tap to draw")
                .font(ChalkTheme.chalkFont(size: size.width * 0.055))
        }
        .foregroundStyle(.white.opacity(0.22))
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

#Preview {
    BoardCanvasView(board: .preview)
        .aspectRatio(BoardGeometry.aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding()
}
