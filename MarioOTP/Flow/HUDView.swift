import SwiftUI

/// Close button, the game-style score pill, and sound.
struct TopBar: View {
    let coins: Int
    let score: Int
    let isMuted: Bool
    let onClose: () -> Void
    let onToggleMute: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RoundButton(symbol: "xmark", label: "Start over", action: onClose)
            Spacer(minLength: 0)
            ScorePill(coins: coins, score: score)
            RoundButton(symbol: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        label: isMuted ? "Turn sound on" : "Turn sound off",
                        action: onToggleMute)
        }
    }
}

private struct ScorePill: View {
    let coins: Int
    let score: Int

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                PixelSprite(image: SpriteImage.coin, size: CGSize(width: 10, height: 15))
                (Text("×").foregroundStyle(Theme.ink3) + Text(String(format: "%02d", coins)))
                    .contentTransition(.numericText(value: Double(coins)))
            }
            Rectangle()
                .fill(Theme.line)
                .frame(width: 1, height: 18)
            Self.scoreText(score)
                .contentTransition(.numericText(value: Double(score)))
        }
        .font(.system(size: 15, weight: .heavy, design: .monospaced))
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Capsule().fill(Theme.card))
        .overlay(Capsule().strokeBorder(Theme.line))
        .softShadow(contact: 0.03, ambient: 0.04, radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coins) coins, \(score) points")
    }

    /// Six digits like an arcade score, with the leading zeros dimmed.
    private static func scoreText(_ score: Int) -> Text {
        let digits = String(format: "%06d", score)
        let significant = score == 0 ? "" : String(score)
        let padding = String(digits.dropLast(significant.count))
        return Text(padding).foregroundStyle(Theme.ink3) + Text(significant)
    }
}

struct RoundButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.card))
                .overlay(Circle().strokeBorder(Theme.line))
                .softShadow(contact: 0.03, ambient: 0.04, radius: 6, y: 2)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

/// Sinks a little under the finger, like a key.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
