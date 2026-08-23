import SwiftUI
import UIKit

/// Renders a board for display: slate, bullets, and the rasterised ink. The
/// widget uses this directly; the app uses it only for the bullets layer,
/// because there the live PencilKit canvas draws the ink instead.
struct BoardCanvasView: View {

    let board: Board
    /// Pre-loaded ink. The widget hands in an image it read from the App Group.
    var ink: UIImage?
    /// How many bullets fit before the list is truncated with a "+n more".
    var maxBullets: Int = 8
    /// The app paints its own slate; the widget uses `containerBackground`.
    var showsBackground: Bool = true
    var showsEmptyHint: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                if showsBackground {
                    ChalkboardBackground()
                }

                BulletsLayer(bullets: board.bullets, size: size, maxBullets: maxBullets)
                    .equatable()

                if let ink {
                    Image(uiImage: ink)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .allowsHitTesting(false)
                }

                if showsEmptyHint && board.bullets.allSatisfy(\.isBlank) {
                    EmptyBoardHint(size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

/// Loads the ink PNG from the App Group. Cheap enough to call per render — the
/// widget renders once per change, and the app does not use this path at all.
enum InkImageLoader {
    static func load() -> UIImage? {
        guard BoardFile.hasInkFile else { return nil }
        return UIImage(contentsOfFile: BoardFile.inkURL.path)
    }
}

// MARK: - Bullets

private struct BulletsLayer: View, Equatable {
    let bullets: [BulletItem]
    let size: CGSize
    let maxBullets: Int

    private var written: [BulletItem] { bullets.filter { !$0.isBlank } }
    private var visible: [BulletItem] { Array(written.prefix(maxBullets)) }
    private var overflow: Int { max(0, written.count - maxBullets) }

    var body: some View {
        VStack(alignment: .leading, spacing: size.height * 0.016) {
            ForEach(visible) { item in
                HStack(alignment: .firstTextBaseline, spacing: size.width * 0.025) {
                    Text("•")
                        .font(ChalkTheme.chalkFont(size: size.width * 0.052))
                    Text(item.text)
                        .font(ChalkTheme.chalkFont(size: size.width * 0.052))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(ChalkTheme.chalk.opacity(0.92))
            }

            if overflow > 0 {
                Text("+\(overflow) more")
                    .font(ChalkTheme.chalkFont(size: size.width * 0.040))
                    .foregroundStyle(ChalkTheme.chalk.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, size.width * 0.06)
        .padding(.top, size.height * 0.055)
        .frame(width: size.width, alignment: .leading)
        .allowsHitTesting(false)
    }
}

private struct EmptyBoardHint: View {
    let size: CGSize

    var body: some View {
        VStack(spacing: size.height * 0.02) {
            Image(systemName: "hand.draw")
                .font(.system(size: size.width * 0.11, weight: .light))
            Text("Tap to draw")
                .font(ChalkTheme.chalkFont(size: size.width * 0.055))
        }
        .foregroundStyle(ChalkTheme.chalk.opacity(0.22))
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

#Preview {
    BoardCanvasView(board: .preview)
        .aspectRatio(BoardGeometry.aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding()
}
