import SwiftUI

/// The arcade prize ticket you get for a verified code.
struct TicketView: View {
    let result: RoundResult

    private static let topHeight: CGFloat = 88

    var body: some View {
        let shape = TicketShape(notchY: Self.topHeight, notchRadius: 11, cornerRadius: 18)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell("COINS") {
                    HStack(spacing: 6) {
                        PixelSprite(image: SpriteImage.coin, size: CGSize(width: 11, height: 16))
                        Text("×\(result.coins)")
                    }
                }
                divider
                cell("SCORE") { Text(result.score.formatted()) }
                divider
                cell("TIME") { Text(Self.clock(result.duration)) }
            }
            .frame(height: Self.topHeight)

            Line()
                .stroke(Theme.line, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                .frame(height: 2)
                .padding(.horizontal, 18)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("World 1-\(result.attempts) cleared")
                        .font(.system(size: 13, weight: .heavy).width(.expanded))
                        .foregroundStyle(Theme.ink)
                    Text("NO. \(result.serial)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink3)
                }
                Spacer()
                Barcode(seed: result.serial)
                    .frame(height: 30)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(shape.fill(Theme.card))
        .overlay(shape.stroke(Theme.line, lineWidth: 1))
        .shadow(color: Theme.shadow.opacity(0.16), radius: 14, x: 0, y: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verified in \(Self.clock(result.duration)). \(result.coins) coins, \(result.score) points.")
    }

    private var divider: some View {
        Line(vertical: true)
            .stroke(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
            .frame(width: 1.5)
            .padding(.vertical, 18)
    }

    private func cell<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(spacing: 9) {
            Text(label)
                .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Theme.ink3)
            value()
                .font(.system(size: 21, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
    }

    static func clock(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Rounded card with a half-circle notch bitten out of each side, where the stub tears off.
struct TicketShape: Shape {
    var notchY: CGFloat
    var notchRadius: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = cornerRadius
        let n = notchRadius
        let y = rect.minY + notchY
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
        path.addLine(to: CGPoint(x: rect.maxX, y: y - n))
        path.addRelativeArc(center: CGPoint(x: rect.maxX, y: y), radius: n, startAngle: .degrees(-90), delta: .degrees(-180))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r), radius: r)
        path.addLine(to: CGPoint(x: rect.minX, y: y + n))
        path.addRelativeArc(center: CGPoint(x: rect.minX, y: y), radius: n, startAngle: .degrees(90), delta: .degrees(-180))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
        path.closeSubpath()
        return path
    }
}

private struct Line: Shape {
    var vertical = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if vertical {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
        return path
    }
}

/// Decorative bars derived from the serial, so every ticket looks a little different.
private struct Barcode: View {
    let seed: String

    private var widths: [CGFloat] {
        var bars: [CGFloat] = [2, 1]
        for scalar in seed.unicodeScalars {
            let v = Int(scalar.value)
            bars.append(CGFloat(1 + v % 3))
            bars.append(CGFloat(1 + (v / 3) % 2))
        }
        return bars + [1, 2]
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                Rectangle()
                    .fill(Theme.ink)
                    .frame(width: width)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Glossy ink capsule.
struct ContinueButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("Continue")
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .font(.system(size: 17, weight: .bold).width(.expanded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Capsule().fill(LinearGradient(colors: [Theme.pillTop, Theme.pillBottom],
                                                      startPoint: .top, endPoint: .bottom)))
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.2), .clear],
                                                           startPoint: .top, endPoint: .center), lineWidth: 1))
            .shadow(color: Theme.pillBottom.opacity(0.35), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(PressableStyle())
    }
}
