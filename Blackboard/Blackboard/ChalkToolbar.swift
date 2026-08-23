import SwiftUI

/// The chalk tray: colours, thickness, eraser, undo and wipe — one tap each,
/// no modes to hunt for.
struct ChalkToolbar: View {

    @Binding var tool: ChalkTool
    let canUndo: Bool
    let onUndo: () -> Void
    let onWipe: () -> Void
    let onNotes: () -> Void

    private let thicknesses: [Double] = [
        BoardGeometry.thinChalk,
        BoardGeometry.mediumChalk,
        BoardGeometry.thickChalk
    ]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ForEach(ChalkColor.allCases) { chalk in
                    ChalkStickButton(
                        chalk: chalk,
                        isSelected: tool.color == chalk && !tool.isEraser
                    ) {
                        tool.color = chalk
                        tool.isEraser = false
                    }
                }

                Divider()
                    .frame(height: 26)
                    .overlay(Color.white.opacity(0.15))

                ForEach(thicknesses, id: \.self) { thickness in
                    ThicknessButton(
                        thickness: thickness,
                        isSelected: tool.width == thickness && !tool.isEraser
                    ) {
                        tool.width = thickness
                        tool.isEraser = false
                    }
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

private struct ChalkStickButton: View {
    let chalk: ChalkColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(chalk.color)
                .frame(width: 22, height: isSelected ? 34 : 26)
                .overlay(
                    Capsule().strokeBorder(Color.black.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: chalk.color.opacity(isSelected ? 0.55 : 0), radius: 7)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chalk.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct ThicknessButton: View {
    let thickness: Double
    let isSelected: Bool
    let action: () -> Void

    private var diameter: CGFloat {
        CGFloat(thickness / BoardGeometry.thickChalk) * 16 + 5
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.white.opacity(isSelected ? 0.95 : 0.45))
                .frame(width: diameter, height: diameter)
                .frame(width: 30, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(thickness == BoardGeometry.thinChalk
                            ? "Thin chalk"
                            : thickness == BoardGeometry.mediumChalk ? "Medium chalk" : "Thick chalk")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
