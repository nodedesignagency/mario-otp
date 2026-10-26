import SwiftUI

/// The blocks, the floor and Mario. While a run plays, the whole stage is redrawn every frame
/// from the choreography; otherwise it just reflects what's been typed.
struct StageView: View {
    let model: OTPFlowModel
    let isFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let layout = StageLayout(width: proxy.size.width)
            TimelineView(.animation(paused: model.activeRun == nil)) { timeline in
                let time = model.activeRun.map { timeline.date.timeIntervalSince($0.start) } ?? 0
                StageCanvas(
                    scene: StageScene(input: model.stageInput(time: time, isFocused: isFocused), layout: layout),
                    layout: layout
                )
            }
            .onAppear { model.layout = layout }
            .onChange(of: proxy.size.width) { _, width in
                model.layout = StageLayout(width: width)
            }
        }
        .frame(height: StageLayout.height)
    }
}

private struct StageCanvas: View {
    let scene: StageScene
    let layout: StageLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(scene.rings) { ring in
                RoundedRectangle(cornerRadius: StageLayout.cornerRadius, style: .continuous)
                    .stroke(Theme.green, lineWidth: 1.5)
                    .frame(width: StageLayout.blockSize, height: StageLayout.blockSize)
                    .scaleEffect(ring.scale)
                    .opacity(ring.opacity)
                    .position(ring.center)
            }

            // Coins sit behind the blocks so they appear to pop out of them.
            ForEach(scene.coins) { coin in
                PixelSprite(image: SpriteImage.coin, size: CGSize(width: 16, height: 24))
                    .scaleEffect(x: coin.spin, y: 1)
                    .opacity(coin.opacity)
                    .position(coin.center)
            }

            ForEach(scene.blocks) { block in
                OTPBlockView(state: block)
                    .opacity(block.opacity)
                    .offset(block.offset)
                    .position(block.center)
            }

            GroundStrip(emphasized: scene.mario != nil)
                .frame(width: layout.width, height: StageLayout.groundHeight)
                .position(x: layout.centerX, y: layout.groundY + StageLayout.groundHeight / 2)

            if let pose = scene.mario {
                PixelSprite(image: SpriteImage.mario(pose.frame),
                            size: CGSize(width: StageLayout.marioSize, height: StageLayout.marioSize))
                    .scaleEffect(x: pose.facing == .left ? -1 : 1, y: 1)
                    .position(x: pose.x, y: layout.groundY - StageLayout.marioSize / 2 - pose.lift)
                    .transition(.opacity)
            }

            if let bubble = scene.bubble {
                PixelSprite(image: SpriteImage.question, size: CGSize(width: 16, height: 22))
                    .scaleEffect(bubble.scale)
                    .opacity(bubble.opacity)
                    .position(bubble.center)
            }

            if !scene.confetti.isEmpty {
                ConfettiLayer(pieces: scene.confetti, layout: layout)
            }
        }
        .frame(width: layout.width, height: StageLayout.height, alignment: .topLeading)
    }
}

private struct GroundStrip: View {
    let emphasized: Bool

    var body: some View {
        Image(decorative: SpriteImage.brick, scale: 0.5)
            .interpolation(.none)
            .resizable(resizingMode: .tile)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.12),
                        .init(color: .black, location: 0.88),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing)
            }
            .opacity(emphasized ? 0.9 : 0.28)
            .animation(.easeOut(duration: 0.4), value: emphasized)
    }
}

/// Pixel confetti. The canvas reaches above the stage so pieces can fly over the headline.
private struct ConfettiLayer: View {
    static let overhang: CGFloat = 160

    let pieces: [ConfettiPiece]
    let layout: StageLayout

    var body: some View {
        Canvas { context, _ in
            context.translateBy(x: 0, y: Self.overhang)
            for piece in pieces {
                var pieceContext = context
                pieceContext.translateBy(x: piece.center.x, y: piece.center.y)
                pieceContext.rotate(by: .radians(piece.rotation))
                pieceContext.opacity = piece.opacity
                let rect = CGRect(x: -piece.size / 2, y: -piece.size / 2, width: piece.size, height: piece.size)
                pieceContext.fill(Path(rect), with: .color(Theme.confetti[piece.palette % Theme.confetti.count]))
            }
        }
        .frame(width: layout.width, height: StageLayout.height + Self.overhang)
        .position(x: layout.centerX, y: (StageLayout.height - Self.overhang) / 2)
        .allowsHitTesting(false)
    }
}
