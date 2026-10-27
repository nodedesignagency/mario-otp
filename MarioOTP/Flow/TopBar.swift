import SwiftUI

/// Start over on the left, sound on the right.
struct TopBar: View {
    let isMuted: Bool
    let onClose: () -> Void
    let onToggleMute: () -> Void

    var body: some View {
        HStack {
            RoundButton(symbol: "xmark", label: "Start over", action: onClose)
            Spacer(minLength: 0)
            RoundButton(symbol: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        label: isMuted ? "Turn sound on" : "Turn sound off",
                        action: onToggleMute)
        }
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
