import SwiftUI

/// One OTP box. Sleek glowing tile while you type; a gold "?" block when `gold` reaches 1.
struct OTPBlockView: View {
    let state: BlockState

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: StageLayout.cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            BlockBody(tone: state.tone, gold: state.gold, glow: state.glow)
                .animation(.easeOut(duration: 0.22), value: state.tone)

            ZStack {
                switch state.glyph {
                case .blank:
                    EmptyView()
                case .digit(let digit):
                    Text(String(digit))
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                case .question:
                    PixelSprite(image: SpriteImage.question, size: CGSize(width: 19, height: 26))
                        .transition(.opacity)
                case .check:
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.green.opacity(0.9), radius: 6)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .opacity(state.glyphOpacity)
            .animation(.spring(response: 0.34, dampingFraction: 0.55), value: state.glyph)

            if state.showsCaret {
                Caret()
            }

            shape
                .fill(Color.white)
                .opacity(state.flash * 0.9)
        }
        .frame(width: StageLayout.blockSize, height: StageLayout.blockSize)
    }
}

private struct BlockBody: View {
    let tone: BlockTone
    let gold: Double
    let glow: Double

    var body: some View {
        let style = BlockStyle(tone)
        let shape = RoundedRectangle(cornerRadius: StageLayout.cornerRadius, style: .continuous)
        ZStack {
            shape.fill(Theme.blockFill)
            shape.fill(style.tint.opacity(style.tintAmount))
            shape.fill(LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .center))
            shape.strokeBorder(style.stroke, lineWidth: style.lineWidth)
            // Light leaking in from the rim, like the reference's neon tiles.
            shape.strokeBorder(style.tint, lineWidth: 8)
                .blur(radius: 6)
                .opacity(style.innerGlow * glow)
                .clipShape(shape)
            if gold > 0 {
                GoldFace().opacity(gold)
            }
        }
        .background {
            shape.fill(style.tint)
                .blur(radius: 14)
                .opacity(style.outerGlow * glow * (1 - gold))
            shape.fill(style.tint)
                .blur(radius: 28)
                .offset(y: 12)
                .opacity(style.outerGlow * 0.6 * glow * (1 - gold))
            shape.fill(Theme.gold)
                .blur(radius: 18)
                .opacity(0.65 * gold * glow)
        }
    }
}

private struct BlockStyle {
    var tint: Color
    var tintAmount: Double
    var stroke: Color
    var lineWidth: CGFloat
    var innerGlow: Double
    var outerGlow: Double

    init(_ tone: BlockTone) {
        switch tone {
        case .empty:
            self.init(tint: Theme.orange, tintAmount: 0, stroke: .white.opacity(0.09), lineWidth: 1, innerGlow: 0, outerGlow: 0)
        case .active:
            self.init(tint: Theme.orange, tintAmount: 0.04, stroke: Theme.orange, lineWidth: 1.5, innerGlow: 0.3, outerGlow: 0.15)
        case .filled:
            self.init(tint: Theme.orange, tintAmount: 0, stroke: .white.opacity(0.16), lineWidth: 1, innerGlow: 0, outerGlow: 0)
        case .pending:
            self.init(tint: Theme.orange, tintAmount: 0.12, stroke: Theme.orange, lineWidth: 2, innerGlow: 0.9, outerGlow: 0.55)
        case .correct:
            self.init(tint: Theme.green, tintAmount: 0.14, stroke: Theme.green, lineWidth: 2, innerGlow: 0.8, outerGlow: 0.5)
        case .wrong:
            self.init(tint: Theme.red, tintAmount: 0.16, stroke: Theme.red, lineWidth: 2, innerGlow: 0.85, outerGlow: 0.55)
        }
    }

    private init(tint: Color, tintAmount: Double, stroke: Color, lineWidth: CGFloat, innerGlow: Double, outerGlow: Double) {
        self.tint = tint
        self.tintAmount = tintAmount
        self.stroke = stroke
        self.lineWidth = lineWidth
        self.innerGlow = innerGlow
        self.outerGlow = outerGlow
    }
}

/// The classic question block: warm gold face with a rivet in each corner.
private struct GoldFace: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StageLayout.cornerRadius, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Theme.goldLight, Theme.gold, Theme.goldDeep],
                                      startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(Theme.goldEdge, lineWidth: 2)
            ForEach(0..<4) { corner in
                Rectangle()
                    .fill(Theme.goldEdge)
                    .frame(width: 4, height: 4)
                    .offset(x: corner % 2 == 0 ? -20 : 20, y: corner < 2 ? -20 : 20)
            }
        }
    }
}

private struct Caret: View {
    var body: some View {
        Capsule()
            .fill(Theme.orange)
            .frame(width: 2.5, height: 26)
            .phaseAnimator([1.0, 0.15]) { content, opacity in
                content.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.55)
            }
    }
}
