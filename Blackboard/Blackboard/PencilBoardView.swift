import PencilKit
import SwiftUI

/// The live drawing surface. Transparent, so the slate and the bullets painted
/// underneath show through, and exactly the size of the widget's board.
struct PencilBoardView: UIViewRepresentable {

    @ObservedObject var controller: DrawingController
    let inkRevision: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> BoardCanvas {
        let canvas = BoardCanvas()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // PencilKit adapts ink colour to the interface style; pinning the
        // canvas to dark is what keeps white chalk white.
        canvas.overrideUserInterfaceStyle = .dark
        canvas.isScrollEnabled = false
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.bouncesZoom = false
        canvas.contentInset = .zero
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.delegate = context.coordinator

        controller.attach(canvas)

        // The board's real size is only known once it has been laid out, and
        // both the chalk width and the saved drawing depend on it.
        let coordinator = context.coordinator
        canvas.onLayout = { [weak coordinator] size in
            guard let coordinator else { return }
            coordinator.controller.canvasResized(to: size, inkRevision: coordinator.inkRevision)
        }
        return canvas
    }

    func updateUIView(_ canvas: BoardCanvas, context: Context) {
        context.coordinator.inkRevision = inkRevision
        // Deferred: reloading the drawing publishes state, and doing that
        // inside a SwiftUI update pass is what produces the "publishing
        // changes from within view updates" complaint.
        let controller = controller
        let revision = inkRevision
        Task { @MainActor in
            controller.syncFromDisk(revision: revision)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let controller: DrawingController
        var inkRevision = UUID()

        init(controller: DrawingController) {
            self.controller = controller
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // PencilKit calls this on the main thread.
            MainActor.assumeIsolated {
                controller.drawingDidChange()
            }
        }
    }
}

/// PKCanvasView does not report its size to SwiftUI, so it has to be asked.
final class BoardCanvas: PKCanvasView {
    var onLayout: (@MainActor (CGSize) -> Void)?

    private var lastReportedSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.size != lastReportedSize else { return }
        lastReportedSize = bounds.size
        onLayout?(bounds.size)
    }
}
