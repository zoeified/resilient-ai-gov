import PencilKit
import SwiftUI

struct ChalkTool: Equatable {
    /// Fraction of board width, so chalk looks the same weight on an iPhone
    /// board and a much larger iPad one.
    var width: Double = BoardGeometry.mediumChalk
    var isEraser: Bool = false
}

/// Owns the live PencilKit canvas: the tool, the undo stack, and the debounced
/// job that turns what you drew into files the widget can read.
@MainActor
final class DrawingController: ObservableObject {

    @Published var tool = ChalkTool() {
        didSet { applyTool() }
    }

    /// On iPad, ignore fingers and palms once you pick up the Pencil.
    @Published var pencilOnly: Bool {
        didSet {
            AppGroup.defaults.set(pencilOnly, forKey: Self.pencilOnlyKey)
            canvas?.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        }
    }

    @Published private(set) var canUndo = false
    /// Live, unlike `Board.hasInk`, which lags by the save debounce.
    @Published private(set) var hasInk = false

    private static let pencilOnlyKey = "pencilOnly"
    private static let undoDepth = 25

    private let store: BoardStore
    private weak var canvas: PKCanvasView?

    /// Snapshots of the drawing *before* each change. PencilKit's own undo
    /// manager comes off the responder chain and is easy to lose in SwiftUI;
    /// an explicit stack is predictable.
    private var undoStack: [Data] = []
    private var currentSnapshot = Data()

    private var canvasWidth: CGFloat = 0
    private var appliedInkRevision: UUID?
    private var isApplyingProgrammatically = false
    private var saveTask: Task<Void, Never>?

    init(store: BoardStore) {
        self.store = store
        self.pencilOnly = AppGroup.defaults.bool(forKey: Self.pencilOnlyKey)
    }

    // MARK: - Canvas lifecycle

    func attach(_ canvas: PKCanvasView) {
        self.canvas = canvas
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
    }

    /// Called from the canvas's own layout pass, which is the first moment the
    /// board's real size is known — and again on an iPad rotation.
    func canvasResized(to size: CGSize, inkRevision: UUID) {
        guard let canvas, size.width > 1 else { return }
        let previousWidth = canvasWidth
        canvasWidth = size.width
        applyTool()

        guard previousWidth > 1 else {
            // First layout: take whatever is on disk.
            syncFromDisk(revision: inkRevision, force: true)
            return
        }
        guard abs(previousWidth - size.width) > 0.5 else { return }

        // Rescale what is already on screen rather than reloading it, so
        // strokes that have not hit the disk yet survive a rotation.
        let scale = size.width / previousWidth
        isApplyingProgrammatically = true
        canvas.drawing = canvas.drawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
        isApplyingProgrammatically = false

        currentSnapshot = canvas.drawing.dataRepresentation()
        // The snapshots were taken at the old size and would jump if restored.
        undoStack.removeAll()
        canUndo = false
        scheduleSave()
    }

    /// Reloads the drawing when the ink on disk changed underneath us — a wipe
    /// from the widget, or an undone wipe.
    func syncFromDisk(revision: UUID, force: Bool = false) {
        guard force || appliedInkRevision != revision else { return }
        guard let canvas, canvasWidth > 1 else { return }
        appliedInkRevision = revision

        let drawing = loadDrawingScaledToCanvas()
        isApplyingProgrammatically = true
        canvas.drawing = drawing
        isApplyingProgrammatically = false

        currentSnapshot = drawing.dataRepresentation()
        hasInk = !drawing.strokes.isEmpty
        undoStack.removeAll()
        canUndo = false
    }

    private func loadDrawingScaledToCanvas() -> PKDrawing {
        guard let data = BoardFile.loadDrawingData(),
              let drawing = try? PKDrawing(data: data)
        else { return PKDrawing() }

        // The board keeps a fixed aspect ratio, so a board drawn on another
        // screen size only needs a uniform scale to land in the same place.
        let savedWidth = CGFloat(store.board.canvasWidth)
        guard savedWidth > 1, abs(savedWidth - canvasWidth) > 0.5 else { return drawing }
        let scale = canvasWidth / savedWidth
        return drawing.transformed(using: CGAffineTransform(scaleX: scale, y: scale))
    }

    // MARK: - Tools

    private func applyTool() {
        guard let canvas, canvasWidth > 1 else { return }
        if tool.isEraser {
            canvas.tool = PKEraserTool(.bitmap, width: CGFloat(BoardGeometry.eraser) * canvasWidth)
        } else {
            // `.pencil` ink is textured and tilt-sensitive — it reads as chalk
            // on a dark board in a way `.pen` never does.
            canvas.tool = PKInkingTool(
                .pencil,
                color: .white,
                width: CGFloat(tool.width) * canvasWidth
            )
        }
    }

    // MARK: - Editing

    func drawingDidChange() {
        guard !isApplyingProgrammatically, let canvas else { return }
        undoStack.append(currentSnapshot)
        if undoStack.count > Self.undoDepth {
            undoStack.removeFirst(undoStack.count - Self.undoDepth)
        }
        currentSnapshot = canvas.drawing.dataRepresentation()
        hasInk = !canvas.drawing.strokes.isEmpty
        canUndo = true
        scheduleSave()
    }

    func undo() {
        guard let canvas, let previous = undoStack.popLast() else { return }
        let drawing = (try? PKDrawing(data: previous)) ?? PKDrawing()
        isApplyingProgrammatically = true
        canvas.drawing = drawing
        isApplyingProgrammatically = false
        currentSnapshot = previous
        hasInk = !drawing.strokes.isEmpty
        canUndo = !undoStack.isEmpty
        scheduleSave()
    }

    func clearCanvas() {
        guard let canvas else { return }
        isApplyingProgrammatically = true
        canvas.drawing = PKDrawing()
        isApplyingProgrammatically = false
        currentSnapshot = Data()
        hasInk = false
        undoStack.removeAll()
        canUndo = false
    }

    // MARK: - Saving

    /// Rasterising the ink is the expensive part, so it waits for the pen to
    /// come to rest rather than running per stroke.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    /// Writes immediately — on backgrounding, so the widget is already correct
    /// by the time you look at the Home Screen.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        persist()
    }

    private func persist() {
        guard let canvas, canvasWidth > 1 else { return }
        let drawing = canvas.drawing
        let size = CGSize(width: canvasWidth, height: canvasWidth / BoardGeometry.aspect)
        let png = InkRenderer.png(from: drawing, size: size)
        store.inkChanged(
            drawing: drawing.dataRepresentation(),
            png: png,
            canvasWidth: canvasWidth
        )
    }
}

enum InkRenderer {

    /// Rasterises the strokes on a transparent background, at 3× the board's
    /// point size so the widget shows crisp chalk on any screen.
    static func png(from drawing: PKDrawing, size: CGSize) -> Data? {
        guard !drawing.strokes.isEmpty, size.width > 1, size.height > 1 else { return nil }

        // PencilKit renders ink for the *current* interface style, and would
        // otherwise flip white chalk to black. Pin it to dark.
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            image = drawing.image(
                from: CGRect(origin: .zero, size: size),
                scale: BoardGeometry.renderScale
            )
        }
        return image?.pngData()
    }
}
