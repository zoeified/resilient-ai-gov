import Foundation
import WidgetKit

/// Everything on disk, in the App Group container so the widget can see it:
///
///   board.json     bullets + metadata
///   drawing.data   PencilKit's own representation, for editing
///   ink.png        the same strokes rasterised on a transparent background,
///                  which is all the widget needs to display them
///
/// Deliberately free of actor isolation and of any PencilKit import: the app,
/// the widget and App Intents all go through here.
enum BoardFile {

    static var directory: URL {
        if let shared = AppGroup.containerURL { return shared }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var usesAppGroup: Bool { AppGroup.isConfigured }

    static var boardURL: URL { directory.appendingPathComponent("board.json") }
    static var drawingURL: URL { directory.appendingPathComponent("drawing.data") }
    static var inkURL: URL { directory.appendingPathComponent("ink.png") }

    private static var boardBackupURL: URL { directory.appendingPathComponent("board-backup.json") }
    private static var drawingBackupURL: URL { directory.appendingPathComponent("drawing-backup.data") }
    private static var inkBackupURL: URL { directory.appendingPathComponent("ink-backup.png") }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Board

    static func loadBoard() -> Board {
        guard let data = try? Data(contentsOf: boardURL),
              let board = try? decoder.decode(Board.self, from: data)
        else { return .empty }
        return board
    }

    static func saveBoard(_ board: Board) {
        guard let data = try? encoder.encode(board) else { return }
        try? data.write(to: boardURL, options: .atomic)
    }

    // MARK: - Ink

    static func loadDrawingData() -> Data? {
        try? Data(contentsOf: drawingURL)
    }

    /// `png` is nil when the drawing is empty — the file is removed rather than
    /// left holding a stale picture.
    static func saveInk(drawing: Data, png: Data?) {
        try? drawing.write(to: drawingURL, options: .atomic)
        if let png {
            try? png.write(to: inkURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: inkURL)
        }
    }

    static var hasInkFile: Bool {
        FileManager.default.fileExists(atPath: inkURL.path)
    }

    // MARK: - Wiping

    /// Wipes the board, keeping one generation of backup so the wipe can be
    /// undone — including when it was triggered from the widget.
    @discardableResult
    static func wipe() -> Board {
        let current = loadBoard()
        if !current.isEmpty {
            move(boardURL, to: boardBackupURL)
            move(drawingURL, to: drawingBackupURL)
            move(inkURL, to: inkBackupURL)
        }
        try? FileManager.default.removeItem(at: drawingURL)
        try? FileManager.default.removeItem(at: inkURL)

        var cleared = Board()
        cleared.touch()
        saveBoard(cleared)
        return cleared
    }

    static var hasBackup: Bool {
        FileManager.default.fileExists(atPath: boardBackupURL.path)
    }

    /// Puts the backup back and returns it, or nil when there is nothing to
    /// restore.
    static func restoreBackup() -> Board? {
        guard hasBackup else { return nil }
        move(boardBackupURL, to: boardURL)
        move(drawingBackupURL, to: drawingURL)
        move(inkBackupURL, to: inkURL)

        var restored = loadBoard()
        restored.touch()
        saveBoard(restored)
        return restored
    }

    static func clearBackup() {
        for url in [boardBackupURL, drawingBackupURL, inkBackupURL] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Replaces the destination, and treats a missing source as "remove the
    /// destination" so backup and live state never disagree.
    private static func move(_ source: URL, to destination: URL) {
        let manager = FileManager.default
        try? manager.removeItem(at: destination)
        guard manager.fileExists(atPath: source.path) else { return }
        try? manager.moveItem(at: source, to: destination)
    }
}

/// Two-tap arming for the widget's wipe button. A single stray tap on the Home
/// Screen should never erase the board, so the first tap arms and the second
/// within the window actually wipes.
enum WipeArm {
    static let window: TimeInterval = 6

    private static let key = "wipeArmedAt"

    static var armedAt: Date? {
        let stamp = AppGroup.defaults.double(forKey: key)
        guard stamp > 0 else { return nil }
        return Date(timeIntervalSinceReferenceDate: stamp)
    }

    static var isArmed: Bool {
        guard let armedAt else { return false }
        return Date().timeIntervalSince(armedAt) < window
    }

    /// When the current arming lapses, so the widget can schedule a refresh.
    static var expiry: Date? {
        guard let armedAt, isArmed else { return nil }
        return armedAt.addingTimeInterval(window)
    }

    static func arm() {
        AppGroup.defaults.set(Date().timeIntervalSinceReferenceDate, forKey: key)
    }

    static func disarm() {
        AppGroup.defaults.removeObject(forKey: key)
    }
}

/// Observable wrapper the app draws from. The widget never touches this — it
/// reads `BoardFile` directly.
@MainActor
final class BoardStore: ObservableObject {

    static let shared = BoardStore()

    @Published private(set) var board: Board
    @Published private(set) var canUndoWipe: Bool
    /// Bumped whenever the ink on disk changes underneath the canvas — a wipe,
    /// an undone wipe, or a board edited elsewhere. The canvas watches this to
    /// know when to reload, rather than being reset on every redraw.
    @Published private(set) var inkRevision = UUID()

    private var saveTask: Task<Void, Never>?

    init(board: Board? = nil) {
        self.board = board ?? BoardFile.loadBoard()
        self.canUndoWipe = BoardFile.hasBackup
    }

    var usesAppGroup: Bool { BoardFile.usesAppGroup }

    // MARK: - Ink

    /// Called by the canvas after a stroke settles. The bytes are produced by
    /// the app (PencilKit lives there); this type only files them away.
    func inkChanged(drawing: Data, png: Data?, canvasWidth: CGFloat) {
        BoardFile.saveInk(drawing: drawing, png: png)
        board.hasInk = png != nil
        board.canvasWidth = Double(canvasWidth)
        board.touch()
        scheduleSave()
    }

    // MARK: - Bullets

    func addBullet(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        board.bullets.append(BulletItem(text: trimmed))
        board.touch()
        scheduleSave()
    }

    /// Blank text is kept while a row is being edited — deleting a bullet the
    /// moment you clear it to retype would be maddening. `saveNow()` tidies up
    /// when editing finishes.
    func updateBullet(id: UUID, text: String) {
        guard let index = board.bullets.firstIndex(where: { $0.id == id }) else { return }
        board.bullets[index].text = text
        board.touch()
        scheduleSave()
    }

    func removeBullets(at offsets: IndexSet) {
        board.bullets.remove(atOffsets: offsets)
        board.touch()
        scheduleSave()
    }

    func moveBullets(from offsets: IndexSet, to destination: Int) {
        board.bullets.move(fromOffsets: offsets, toOffset: destination)
        board.touch()
        scheduleSave()
    }

    func clearBullets() {
        guard !board.bullets.isEmpty else { return }
        board.bullets.removeAll()
        board.touch()
        scheduleSave()
    }

    // MARK: - Wiping

    func wipe() {
        // A save scheduled by the last stroke would otherwise fire after the
        // wipe and write the old board straight back.
        saveTask?.cancel()
        saveTask = nil
        board = BoardFile.wipe()
        canUndoWipe = BoardFile.hasBackup
        inkRevision = UUID()
        WipeArm.disarm()
        reloadWidgets()
    }

    func undoWipe() {
        saveTask?.cancel()
        saveTask = nil
        guard let restored = BoardFile.restoreBackup() else { return }
        board = restored
        canUndoWipe = false
        inkRevision = UUID()
        reloadWidgets()
    }

    func dismissUndoWipe() {
        BoardFile.clearBackup()
        canUndoWipe = false
    }

    // MARK: - Persistence

    /// Coalesces the flurry of writes that an editing session produces.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [board] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            BoardFile.saveBoard(board)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Writes immediately — used when the app leaves the foreground, so the
    /// widget is already correct by the time you look at the Home Screen.
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        board.pruneBlankBullets()
        BoardFile.saveBoard(board)
        reloadWidgets()
    }

    /// Picks up changes made while the app was backgrounded: a wipe from the
    /// widget, or a note added through Siri.
    func reloadFromDisk() {
        let disk = BoardFile.loadBoard()
        guard disk.updatedAt > board.updatedAt else { return }
        board = disk
        inkRevision = UUID()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
