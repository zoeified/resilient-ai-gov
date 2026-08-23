import SwiftUI

/// The chalk tray. One colour — white — so what is left is thickness, eraser,
/// undo, notes and wipe. One tap each, no modes to hunt for.
struct ChalkToolbar: View {

    @Binding var tool: ChalkTool
    @Binding var pencilOnly: Bool
    /// Palm rejection is only meaningful where there is a Pencil.
    let showsPencilToggle: Bool
    let canUndo: Bool
    let onUndo: () -> Void
    let onNotes: () -> Void
    let onWipe: () -> Void

    private let thicknesses: [Double] = [
        BoardGeometry.thinChalk,
        BoardGeometry.mediumChalk,
        BoardGeometry.thickChalk
    ]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                ForEach(thicknesses, id: \.self) { thickness in
                    ThicknessButton(
                        thickness: thickness,
                        isSelected: tool.width == thickness && !tool.isEraser
                    ) {
                        tool.width = thickness
                        tool.isEraser = false
                    }
                }

                if showsPencilToggle {
                    Divider()
                        .frame(height: 26)
                        .overlay(Color.white.opacity(0.15))

                    Toggle(isOn: $pencilOnly) {
                        Label("Pencil only", systemImage: "applepencil")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .toggleStyle(.button)
                    .labelStyle(.titleAndIcon)
                    .tint(.white.opacity(0.9))
                    .foregroundStyle(pencilOnly ? .white : .white.opacity(0.6))
                    .accessibilityHint("Ignore fingers and palms while drawing.")
                }
            }

            HStack(spacing: 10) {
                TrayButton(
                    title: "Eraser",
                    systemImage: "eraser.fill",
                    isSelected: tool.isEraser
                ) {
                    tool.isEraser.toggle()
                }

                TrayButton(title: "Undo", systemImage: "arrow.uturn.backward") {
                    onUndo()
                }
                .disabled(!canUndo)
                .opacity(canUndo ? 1 : 0.35)

                TrayButton(title: "Notes", systemImage: "list.bullet") {
                    onNotes()
                }

                TrayButton(title: "Wipe", systemImage: "wind", isDestructive: true) {
                    onWipe()
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

/// A chalk dot at the size it will actually draw.
private struct ThicknessButton: View {
    let thickness: Double
    let isSelected: Bool
    let action: () -> Void

    private var diameter: CGFloat {
        CGFloat(thickness / BoardGeometry.thickChalk) * 18 + 6
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(ChalkTheme.chalk.opacity(isSelected ? 1 : 0.4))
                .frame(width: diameter, height: diameter)
                .shadow(color: .white.opacity(isSelected ? 0.5 : 0), radius: 6)
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var label: String {
        switch thickness {
        case BoardGeometry.thinChalk: return "Thin chalk"
        case BoardGeometry.thickChalk: return "Thick chalk"
        default: return "Medium chalk"
        }
    }
}

private struct TrayButton: View {
    let title: String
    let systemImage: String
    var isSelected: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        if isDestructive { return Color(red: 0.98, green: 0.72, blue: 0.66) }
        return isSelected ? .white : .white.opacity(0.85)
    }
}
