import SwiftUI
import UIKit

struct BoardScreen: View {

    @ObservedObject var store: BoardStore
    @Binding var pendingDestination: DeepLink.Destination?

    @StateObject private var drawing: DrawingController
    @Environment(\.scenePhase) private var scenePhase

    @State private var draftBullet = ""
    @State private var showingNotes = false
    @State private var showingWipeToast = false
    @FocusState private var bulletFieldFocused: Bool

    init(store: BoardStore, pendingDestination: Binding<DeepLink.Destination?>) {
        self.store = store
        self._pendingDestination = pendingDestination
        self._drawing = StateObject(wrappedValue: DrawingController(store: store))
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        ZStack {
            roomBackground

            VStack(spacing: 16) {
                header
                board
                quickAddField
                toolbar
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            // Without a ceiling the board would sprawl across a 13-inch iPad
            // put the chalk tray an arm's length from the drawing.
            .frame(maxWidth: 760)

            if showingWipeToast && store.canUndoWipe {
                wipeToast
            }
        }
        .sheet(isPresented: $showingNotes) {
            NotesEditorView(store: store)
        }
        .onChange(of: pendingDestination) { _, destination in
            handle(destination)
        }
        .onAppear {
            handle(pendingDestination)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // A wipe from the widget, or a note added by Siri, happened in
                // another process — pick it up.
                store.reloadFromDisk()
            case .inactive, .background:
                drawing.flush()
                store.saveNow()
            @unknown default:
                break
            }
        }
    }

    // MARK: - Pieces

    private var roomBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.07, blue: 0.08), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Blackboard")
                .font(ChalkTheme.chalkFont(size: 22))
                .foregroundStyle(ChalkTheme.chalk.opacity(0.85))

            Spacer()

            if !store.usesAppGroup {
                Label("Widget not linked", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.98, green: 0.78, blue: 0.45))
                    .accessibilityHint("Add the App Group capability to both targets.")
            }
        }
        .padding(.horizontal, 22)
    }

    private var board: some View {
        ZStack {
            BoardCanvasView(
                board: store.board,
                ink: nil,
                maxBullets: 8,
                showsBackground: true,
                showsEmptyHint: !drawing.hasInk
            )

            PencilBoardView(controller: drawing, inkRevision: store.inkRevision)
        }
        .aspectRatio(BoardGeometry.aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.65), radius: 20, x: 0, y: 12)
        .padding(.horizontal, 14)
        .accessibilityLabel("Blackboard")
        .accessibilityHint("Draw with a finger or Apple Pencil.")
    }

    private var quickAddField: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet")
                .foregroundStyle(.white.opacity(0.45))

            TextField("Add a bullet…", text: $draftBullet)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($bulletFieldFocused)
                .foregroundStyle(.white)
                .onSubmit(commitBullet)

            if !draftBullet.isEmpty {
                Button(action: commitBullet) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .padding(.horizontal, 14)
    }

    private var toolbar: some View {
        ChalkToolbar(
            tool: $drawing.tool,
            pencilOnly: $drawing.pencilOnly,
            showsPencilToggle: isPad,
            canUndo: drawing.canUndo,
            onUndo: {
                drawing.undo()
                Haptics.tap()
            },
            onNotes: { showingNotes = true },
            onWipe: wipe
        )
        .padding(.horizontal, 14)
    }

    private var wipeToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 14) {
                Text("Board wiped")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                Button("Undo") {
                    store.undoWipe()
                    showingWipeToast = false
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.white.opacity(0.16)))
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 130)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                withAnimation { showingWipeToast = false }
                // Once the offer lapses, drop the backup rather than leaving a
                // stale board on disk waiting to be restored days later.
                store.dismissUndoWipe()
            }
        }
    }

    // MARK: - Actions

    private func commitBullet() {
        store.addBullet(draftBullet)
        draftBullet = ""
        Haptics.tap()
    }

    private func wipe() {
        guard !store.board.bullets.isEmpty || drawing.hasInk else { return }
        drawing.flush()
        store.wipe()
        drawing.clearCanvas()
        Haptics.wipe()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingWipeToast = true
        }
    }

    private func handle(_ destination: DeepLink.Destination?) {
        guard let destination else { return }
        switch destination {
        case .note:
            bulletFieldFocused = true
        case .draw:
            bulletFieldFocused = false
        }
        pendingDestination = nil
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func wipe() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
