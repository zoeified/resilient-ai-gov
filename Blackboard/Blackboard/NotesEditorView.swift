import SwiftUI

/// Full editing for the bullet list: add, rename, reorder, delete. The board
/// itself stays a board — text is managed here.
struct NotesEditorView: View {

    @ObservedObject var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.board.bullets) { bullet in
                        BulletRow(bullet: bullet) { newText in
                            store.updateBullet(id: bullet.id, text: newText)
                        }
                    }
                    .onDelete { store.removeBullets(at: $0) }
                    .onMove { store.moveBullets(from: $0, to: $1) }

                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.secondary)
                        TextField("New bullet", text: $draft)
                            .focused($draftFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                store.addBullet(draft)
                                draft = ""
                                draftFocused = true
                            }
                    }
                } header: {
                    Text("Bullets on the board")
                } footer: {
                    Text("These appear at the top of the widget. Long-press a row to reorder.")
                }

                if !store.board.bullets.isEmpty {
                    Section {
                        Button("Clear all bullets", role: .destructive) {
                            store.clearBullets()
                        }
                    }
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if !draft.isEmpty { store.addBullet(draft) }
                        store.saveNow()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct BulletRow: View {
    let bullet: BulletItem
    let onCommit: (String) -> Void

    @State private var text: String

    init(bullet: BulletItem, onCommit: @escaping (String) -> Void) {
        self.bullet = bullet
        self.onCommit = onCommit
        _text = State(initialValue: bullet.text)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("•").foregroundStyle(.secondary)
            TextField("Bullet", text: $text, axis: .vertical)
                .onSubmit { onCommit(text) }
                .onChange(of: text) { _, newValue in
                    // Commit as you type so the widget never lags behind the
                    // list you are looking at.
                    onCommit(newValue)
                }
        }
    }
}
