import WidgetKit
import SwiftUI
import AppIntents

struct BoardEntry: TimelineEntry {
    let date: Date
    let board: Board
    let wipeArmed: Bool
}

struct BoardProvider: TimelineProvider {

    func placeholder(in context: Context) -> BoardEntry {
        BoardEntry(date: Date(), board: .preview, wipeArmed: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        // The widget gallery gets the sample board; the Home Screen gets yours.
        let board = context.isPreview ? Board.preview : BoardFile.load()
        completion(BoardEntry(date: Date(), board: board, wipeArmed: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        let board = BoardFile.load()
        let armed = WipeArm.isArmed
        var entries = [BoardEntry(date: Date(), board: board, wipeArmed: armed)]

        // When the wipe button is armed, schedule the entry that disarms it so
        // the button doesn't sit there looking dangerous forever.
        if armed, let expiry = WipeArm.expiry {
            entries.append(BoardEntry(date: expiry, board: board, wipeArmed: false))
        }

        // Nothing here changes on a schedule — the app and the intents push
        // reloads when the board actually changes.
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct BlackboardWidgetEntryView: View {

    @Environment(\.widgetFamily) private var family
    var entry: BoardEntry

    var body: some View {
        BoardCanvasView(
            board: entry.board,
            liveStroke: nil,
            maxBullets: maxBullets,
            showsBackground: false
        )
        .overlay(alignment: .bottomTrailing) {
            if family != .systemSmall {
                controls
                    .padding(10)
            }
        }
        .containerBackground(for: .widget) {
            ChalkboardBackground()
        }
        // Tapping anywhere else opens the board ready to draw.
        .widgetURL(DeepLink.draw)
    }

    private var maxBullets: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        default: return 8
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Link(destination: DeepLink.note) {
                ControlChip(systemImage: "plus", label: family == .systemMedium ? nil : "Note")
            }

            Button(intent: WipeBoardIntent(immediate: false)) {
                ControlChip(
                    systemImage: entry.wipeArmed ? "exclamationmark.triangle.fill" : "wind",
                    label: entry.wipeArmed ? "Tap to confirm" : (family == .systemMedium ? nil : "Wipe"),
                    isArmed: entry.wipeArmed
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ControlChip: View {
    let systemImage: String
    var label: String?
    var isArmed: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            if let label {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(isArmed ? Color(red: 0.99, green: 0.85, blue: 0.6) : .white.opacity(0.85))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(Color.white.opacity(isArmed ? 0.22 : 0.12))
        )
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct BlackboardWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppGroup.widgetKind, provider: BoardProvider()) { entry in
            BlackboardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Blackboard")
        .description("Your chalkboard, on the Home Screen. Tap to draw, tap again to wipe.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemLarge) {
    BlackboardWidget()
} timeline: {
    BoardEntry(date: Date(), board: .preview, wipeArmed: false)
    BoardEntry(date: Date(), board: .preview, wipeArmed: true)
}
