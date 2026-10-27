import SwiftUI

/// One OTP digit as a keycap: a printed face sitting in a darker skirt. It flips into a gold "?" block
/// while Mario checks it, then turns green or red.
struct KeycapView: View {
    let state: BlockState

    var body: some View {
        let style = KeycapStyle(state)
        ZStack {
            KeycapBody(style: style)
                .animation(.easeOut(duration: 0.2), value: state.tone)
            if state.gold > 0 {
                KeycapBody(style: .questionBlock)
                    .opacity(state.gold)
            }

            ZStack {
                switch state.glyph {
                case .blank:
                    EmptyView()
                case .digit(let digit):
                    Text(String(digit))
                        .font(.system(size: 27, weight: .heavy, design: .monospaced))
                        .foregroundStyle(style.ink)
                        .shadow(color: style.inkShadow, radius: 0, x: 0, y: 2)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                case .question:
                    PixelSprite(image: SpriteImage.question, size: CGSize(width: 19, height: 26))
                        .transition(.opacity)
                case .check:
                    CheckmarkShape()
                        .trim(from: 0, to: state.checkTrim)
                        .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .square, lineJoin: .miter))
                        .frame(width: 26, height: 21)
                }
            }
            .opacity(state.glyphOpacity)
            .offset(y: Keycap.faceCenterOffset)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: state.glyph)

            if state.tone == .active {
                PixelCursor()
                    .offset(y: Keycap.faceCenterOffset + 11)
            }

            Keycap.faceShape
                .fill(.white)
                .padding(Keycap.faceInsets)
                .opacity(state.flash * 0.6)
        }
        .frame(width: StageLayout.blockSize, height: StageLayout.blockSize)
        // The key you're typing into rises a little, like it's waiting to be pressed.
        .offset(y: state.tone == .active ? -2 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.tone == .active)
    }
}

enum Keycap {
    static let faceInsets = EdgeInsets(top: 2.5, leading: 3.5, bottom: 8, trailing: 3.5)
    /// The face sits high in the cap, so its centre is a little above the cap's.
    static let faceCenterOffset: CGFloat = (faceInsets.top - faceInsets.bottom) / 2
    static var faceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: StageLayout.cornerRadius - 3.5, style: .continuous)
    }
}

private struct KeycapBody: View {
    let style: KeycapStyle

    var body: some View {
        let skirt = RoundedRectangle(cornerRadius: StageLayout.cornerRadius, style: .continuous)
        ZStack {
            skirt.fill(style.skirt)
            skirt.strokeBorder(Theme.ink.opacity(style.edge), lineWidth: 0.75)
            ZStack {
                Keycap.faceShape
                    .fill(LinearGradient(colors: [style.faceTop, style.faceBottom], startPoint: .top, endPoint: .bottom))
                Keycap.faceShape
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .clear], startPoint: .top, endPoint: .center),
                                  lineWidth: 1)
                if style.rivets {
                    Rivets()
                }
            }
            .shadow(color: Theme.ink.opacity(0.04), radius: 0.5, x: 0, y: 0.5)
            .padding(Keycap.faceInsets)
        }
        .compositingGroup()
        .softShadow(style.shadowTint, contact: 0.05, ambient: style.ambient, radius: 10, y: 5)
    }
}

/// The four corner bolts of a question block.
private struct Rivets: View {
    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 6
            let size: CGFloat = 4.5
            ForEach(0..<4) { corner in
                Rectangle()
                    .fill(Theme.goldRivet)
                    .frame(width: size, height: size)
                    .position(x: corner % 2 == 0 ? inset + size / 2 : proxy.size.width - inset - size / 2,
                              y: corner < 2 ? inset + size / 2 : proxy.size.height - inset - size / 2)
            }
        }
    }
}

private struct KeycapStyle {
    var skirt = Theme.keySkirt
    var faceTop = Theme.keyFaceTop
    var faceBottom = Theme.keyFaceBottom
    var ink = Theme.ink
    var inkShadow = Color.clear
    var edge = 0.06
    var rivets = false
    var shadowTint = Theme.shadow
    var ambient = 0.07

    static let questionBlock = KeycapStyle(BlockState(id: 0, center: .zero, tone: .pending, glyph: .blank))

    init(_ state: BlockState) {
        switch state.tone {
        case .empty, .active, .filled:
            break
        case .pending:
            skirt = Theme.goldSkirt
            faceTop = Theme.goldLight
            faceBottom = Theme.gold
            ink = .white
            inkShadow = Theme.goldInk.opacity(0.35)
            edge = 0
            rivets = true
            shadowTint = Theme.goldSkirt
            ambient = 0.14
        case .correct where state.isHero:
            skirt = Theme.greenSkirt
            faceTop = Theme.greenLight
            faceBottom = Theme.green
            ink = .white
            edge = 0
            shadowTint = Theme.greenSkirt
            ambient = 0.16
        case .correct:
            skirt = Theme.greenSkirt
            faceTop = Theme.greenFaceTop
            faceBottom = Theme.greenFace
            ink = Theme.greenSkirt
            edge = 0
            shadowTint = Theme.greenSkirt
            ambient = 0.09
        case .wrong:
            skirt = Theme.redSkirt
            faceTop = Theme.redFaceTop
            faceBottom = Theme.redFace
            ink = Theme.redSkirt
            edge = 0
            shadowTint = Theme.redSkirt
            ambient = 0.09
        }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// An old-terminal underscore that blinks hard on and off instead of fading.
private struct PixelCursor: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let visible = abs(Int(context.date.timeIntervalSinceReferenceDate * 2)) % 2 == 0
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 18, height: 4)
                .opacity(visible ? 1 : 0)
        }
    }
}
