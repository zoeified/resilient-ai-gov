import Foundation
import WidgetKit

/// Disk access for the board. Deliberately free of any actor isolation: the
/// app, the widget extension and App Intents all read and write through here.
enum BoardFile {

    private static let fileName = "board.json"
    private static let backupName = "board-backup.json"

    /// The App Group container when configured, otherwise the app's own
    /// Documents directory. The fallback keeps the app usable while you are
    /// still wiring up capabilities — the widget just stays empty.
    static var directory: URL {
        if let shared = AppGroup.containerURL { return shared }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var usesAppGroup: Bool { AppGroup.isConfigured }

    private static var fileURL: URL { directory.appendingPathComponent(fileName) }
    private static var backupURL: URL { directory.appendingPathComponent(backupName) }

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

    static func load() -> Board {
        load(from: fileURL) ?? .empty
    }

    static func save(_ board: Board) {
        write(board, to: fileURL)
    }

    static func loadBackup() -> Board? {
        load(from: backupURL)
    }

    static func clearBackup() {
        try? FileManager.default.removeItem(at: backupURL)
    }

    /// Wipes the board, keeping a copy so the wipe can be undone.
    @discardableResult
    static func wipe() -> Board {
        let current = load()
        if !current.isEmpty {
            write(current, to: backupURL)
        }
        var cleared = Board()
        cleared.touch()
        save(cleared)
        return cleared
    }

    private static func load(from url: URL) -> Board? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Board.self, from: data)
    }

    private static func write(_ board: Board, to url: URL) {
        guard let data = try? encoder.encode(board) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// Two-tap arming for the widget's wipe button. A single stray tap on the Home
/// Screen should never erase the board, so the first tap arms and the second
/// tap within the window actually wipes.
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

    private var saveTask: Task<Void, Never>?

    init(board: Board? = nil) {
        let loaded = board ?? BoardFile.load()
        self.board = loaded
        self.canUndoWipe = BoardFile.loadBackup() != nil
    }

    var usesAppGroup: Bool { BoardFile.usesAppGroup }

    // MARK: - Drawing

    func append(_ stroke: Stroke) {
        board.append(stroke)
        scheduleSave()
    }

    var canUndoStroke: Bool { !board.strokes.isEmpty }

    func undoLastStroke() {
        guard !board.strokes.isEmpty else { return }
        board.strokes.removeLast()
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

    /// Empty text is kept while the row is being edited — deleting a bullet the
    /// moment you clear it to retype would be maddening. `pruneEmptyBullets()`
    /// tidies up when editing finishes.
    func updateBullet(id: UUID, text: String) {
        guard let index = board.bullets.firstIndex(where: { $0.id == id }) else { return }
        board.bullets[index].text = text
        board.touch()
        scheduleSave()
    }

    func pruneEmptyBullets() {
        let kept = board.bullets.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard kept.count != board.bullets.count else { return }
        board.bullets = kept
        board.touch()
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
        board = BoardFile.wipe()
        canUndoWipe = BoardFile.loadBackup() != nil
        WipeArm.disarm()
        reloadWidgets()
    }

    func undoWipe() {
        guard var restored = BoardFile.loadBackup() else { return }
        restored.touch()
        board = restored
        BoardFile.clearBackup()
        canUndoWipe = false
        saveNow()
    }

    func dismissUndoWipe() {
        BoardFile.clearBackup()
        canUndoWipe = false
    }

    // MARK: - Persistence

    /// Coalesces the flurry of writes that a drawing session produces.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [board] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            BoardFile.save(board)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Writes immediately — used when the app leaves the foreground so the
    /// widget is already correct by the time you look at the Home Screen.
    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        pruneEmptyBullets()
        BoardFile.save(board)
        reloadWidgets()
    }

    /// Picks up changes made while the app was backgrounded (a wipe from the
    /// widget, a note added through Siri).
    func reloadFromDisk() {
        let disk = BoardFile.load()
        if disk.updatedAt > board.updatedAt {
            board = disk
        }
        canUndoWipe = BoardFile.loadBackup() != nil
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
