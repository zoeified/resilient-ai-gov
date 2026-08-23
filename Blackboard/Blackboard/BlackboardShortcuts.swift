import AppIntents

/// Siri and Shortcuts entry points. Lives in the app target only — an
/// AppShortcutsProvider belongs to the app bundle, not the extension.
struct BlackboardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddNoteIntent(),
            phrases: ["Add a note to \(.applicationName)"],
            shortTitle: "Add Note",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: WipeBoardIntent(),
            phrases: ["Wipe my \(.applicationName)"],
            shortTitle: "Wipe Board",
            systemImageName: "eraser"
        )
    }
}
