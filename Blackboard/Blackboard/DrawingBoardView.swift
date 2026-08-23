import SwiftUI

struct ChalkTool: Equatable {
    var color: ChalkColor = .white
    var width: Double = BoardGeometry.mediumChalk
    var isEraser: Bool = false

    var effectiveWidth: Double { isEraser ? BoardGeometry.eraser : width }
}

/// The board you actually draw on. It is pinned to the widget's aspect ratio,
/// so the drawing is never cropped or restretched on the Home Screen.
struct DrawingBoardView: View {

    @ObservedObject var store: BoardStore
    let tool: ChalkTool

    @State private var liveStroke: Stroke?

    var body: some View {
        GeometryReader { proxy in
            BoardCanvasView(
                board: store.board,
                liveStroke: liveStroke,
                maxBullets: 8,
                showsBackground: true
            )
            .contentShape(Rectangle())
            .gesture(drawGesture(in: proxy.size))
        }
        .aspectRatio(BoardGeometry.aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(ChalkboardFrame())
        .shadow(color: .black.opacity(0.6), radius: 18, x: 0, y: 10)
        .accessibilityLabel("Blackboard")
        .accessibilityHint("Draw with one finger.")
    }

    private func drawGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = normalized(value.location, in: size)
                if liveStroke == nil {
                    var stroke = Stroke(
                        color: tool.color,
                        width: tool.effectiveWidth,
                        isEraser: tool.isEraser
                    )
                    stroke.points = [point]
                    liveStroke = stroke
                } else {
                    liveStroke?.extend(to: point)
                }
            }
            .onEnded { _ in
                if let stroke = liveStroke {
                    store.append(stroke)
                }
                liveStroke = nil
            }
    }

    private func normalized(_ location: CGPoint, in size: CGSize) -> BoardPoint {
        guard size.width > 0, size.height > 0 else { return BoardPoint(x: 0, y: 0) }
        return BoardPoint(x: location.x / size.width, y: location.y / size.height)
    }
}

/// Wooden surround, so the board reads as a board and not as a dark rectangle.
struct ChalkboardFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [ChalkTheme.frameOuter, ChalkTheme.frameInner, ChalkTheme.frameOuter],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 9
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.45), lineWidth: 1)
            )
            .allowsHitTesting(false)
    }
}
