import SwiftUI

/// Score bar in the black space above the sheet, straight out of World 1-1.
struct HUDView: View {
    let score: Int
    let coins: Int
    let world: Int
    let isMuted: Bool
    let onToggleMute: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            HUDStat("MARIO") {
                Text(String(format: "%06d", score))
                    .contentTransition(.numericText(value: Double(score)))
            }
            Spacer(minLength: 12)
            HUDStat("COINS") {
                HStack(spacing: 5) {
                    PixelSprite(image: SpriteImage.coin, size: CGSize(width: 8, height: 12))
                    Text("×" + String(format: "%02d", coins))
                        .contentTransition(.numericText(value: Double(coins)))
                }
            }
            Spacer(minLength: 12)
            HUDStat("WORLD") {
                Text("1-\(world)")
                    .contentTransition(.numericText(value: Double(world)))
            }
            Spacer(minLength: 12)
            Button(action: onToggleMute) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.08)))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(.white.opacity(0.8))
            .accessibilityLabel(isMuted ? "Turn sound on" : "Turn sound off")
        }
        .font(.system(size: 14, weight: .heavy, design: .monospaced))
        .foregroundStyle(.white.opacity(0.9))
    }
}

private struct HUDStat<Value: View>: View {
    let label: String
    let value: Value

    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
            value
        }
        .accessibilityElement(children: .combine)
    }
}

/// So you can play without a phone number.
struct DemoHint: View {
    let code: String

    var body: some View {
        HStack(spacing: 8) {
            PixelSprite(image: SpriteImage.question, size: CGSize(width: 8, height: 11))
            Text("Demo code")
                .foregroundStyle(.white.opacity(0.55))
            Text(code)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Theme.gold)
                .contentTransition(.numericText())
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        .animation(.snappy, value: code)
        .accessibilityElement(children: .combine)
    }
}
