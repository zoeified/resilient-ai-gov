import AppIntents
import WidgetKit

/// Wipes the board straight from the Home Screen.
///
/// The first tap arms the button, the second within `WipeArm.window` actually
/// wipes. A wiped board is kept as a backup so the app can offer "Undo wipe".
struct WipeBoardIntent: AppIntent {

    static var title: LocalizedStringResource = "Wipe Blackboard"
    static var description = IntentDescription(
        "Erases the blackboard. From the widget, tap once to arm and again to confirm."
    )
    static var openAppWhenRun = false

    /// Shortcuts and Siri skip the two-tap confirmation — you already said it.
    @Parameter(title: "Confirm Immediately", default: true)
    var immediate: Bool

    init() {}

    init(immediate: Bool) {
        self.immediate = immediate
    }

    func perform() async throws -> some IntentResult {
        if immediate || WipeArm.isArmed {
            WipeArm.disarm()
            BoardFile.wipe()
        } else {
            WipeArm.arm()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Adds a bullet without opening the app — useful from Siri, Shortcuts or the
/// Action button.
struct AddNoteIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Blackboard Note"
    static var description = IntentDescription("Adds a bullet to the blackboard.")
    static var openAppWhenRun = false

    @Parameter(title: "Note", requestValueDialog: "What should the board say?")
    var text: String

    init() {}

    init(text: String) {
        self.text = text
    }

    func perform() async throws -> some IntentResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result() }

        var board = BoardFile.load()
        board.bullets.append(BulletItem(text: trimmed))
        board.touch()
        BoardFile.save(board)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
