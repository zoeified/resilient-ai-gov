import SwiftUI

enum ChalkTheme {

    /// Neutral near-black. Not green, not blue — just slate, so white chalk is
    /// the only colour on the board.
    static let slateTop = Color(red: 0.075, green: 0.075, blue: 0.080)
    static let slateBottom = Color(red: 0.025, green: 0.025, blue: 0.028)

    static let chalk = Color(red: 0.97, green: 0.97, blue: 0.96)

    /// Chalkduster ships with iOS.
    static func chalkFont(size: CGFloat) -> Font {
        .custom("Chalkduster", size: size)
    }
}

/// A tiny deterministic generator so the chalk dust lands in the same place on
/// every redraw — a random scatter would shimmer as the widget refreshes.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func nextUnit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
}

private struct DustSpeck {
    let position: CGPoint
    let radius: Double
    let opacity: Double
}

private let chalkDust: [DustSpeck] = {
    var random = SeededRandom(seed: 0xB1AC_B0A2_D001)
    return (0..<220).map { _ in
        DustSpeck(
            position: CGPoint(x: random.nextUnit(), y: random.nextUnit()),
            radius: 0.2 + random.nextUnit() * 1.1,
            opacity: 0.02 + random.nextUnit() * 0.05
        )
    }
}()

private let chalkSmears: [(CGPoint, CGSize, Double)] = {
    var random = SeededRandom(seed: 0x5EA1_7ED)
    return (0..<9).map { _ in
        (
            CGPoint(x: random.nextUnit(), y: random.nextUnit()),
            CGSize(width: 0.18 + random.nextUnit() * 0.34, height: 0.02 + random.nextUnit() * 0.05),
            0.010 + random.nextUnit() * 0.018
        )
    }
}()

/// The slate: near-black, with the ghost of a thousand old lessons.
struct ChalkboardBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ChalkTheme.slateTop, ChalkTheme.slateBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                for smear in chalkSmears {
                    let rect = CGRect(
                        x: smear.0.x * size.width - smear.1.width * size.width / 2,
                        y: smear.0.y * size.height,
                        width: smear.1.width * size.width,
                        height: smear.1.height * size.height
                    )
                    context.fill(
                        Ellipse().path(in: rect),
                        with: .color(.white.opacity(smear.2))
                    )
                }
                for speck in chalkDust {
                    let rect = CGRect(
                        x: speck.position.x * size.width,
                        y: speck.position.y * size.height,
                        width: speck.radius,
                        height: speck.radius
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.white.opacity(speck.opacity))
                    )
                }
            }
        }
    }
}
