import SwiftUI

/// The keys and Mario. While a run plays, the whole stage is redrawn every frame
/// from the choreography; otherwise it just reflects what's been typed.
struct StageView: View {
    let model: OTPFlowModel
    let isFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let layout = StageLayout(width: proxy.size.width)
            TimelineView(.animation(paused: model.activeRun == nil || model.isStageSettled)) { timeline in
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
                    .stroke(Theme.green, lineWidth: 2)
                    .frame(width: StageLayout.blockSize, height: StageLayout.blockSize)
                    .scaleEffect(ring.scale)
                    .opacity(ring.opacity)
                    .position(ring.center)
            }

            // Hit coins rise from behind the keys.
            ForEach(scene.coins.filter { !$0.popsOut }) { coin in
                CoinSprite(coin: coin)
            }

            ForEach(scene.blocks) { block in
                KeycapView(state: block)
                    .scaleEffect(block.scale)
                    .scaleEffect(x: 1, y: block.flip)
                    .opacity(block.opacity)
                    .offset(block.offset)
                    .position(block.center)
                    .zIndex(10 + block.zIndex)
            }

            BrickRoad()
                .frame(width: layout.width, height: StageLayout.groundHeight)
                .position(x: layout.centerX, y: layout.groundY + StageLayout.groundHeight / 2)
                .zIndex(19)

            if let pose = scene.mario {
                PixelSprite(image: SpriteImage.mario(pose.frame),
                            size: CGSize(width: StageLayout.marioSize, height: StageLayout.marioSize))
                    .scaleEffect(x: pose.facing == .left ? -1 : 1, y: 1)
                    .position(x: pose.x, y: layout.groundY - StageLayout.marioSize / 2 - pose.lift)
                    .zIndex(21)
            }

            if let speech = scene.speech {
                SpeechBubble(wrongSlots: speech.wrongSlots, tailOnRight: speech.tailOnRight)
                    .scaleEffect(speech.scale, anchor: speech.tailOnRight ? .bottomTrailing : .bottomLeading)
                    .position(speech.center)
                    .zIndex(22)
                    .transition(.opacity)
            }

            // The finale's coin fountain flies in front of everything.
            ForEach(scene.coins.filter(\.popsOut)) { coin in
                CoinSprite(coin: coin)
                    .zIndex(23)
            }
        }
        .frame(width: layout.width, height: StageLayout.height, alignment: .topLeading)
    }
}

private struct CoinSprite: View {
    let coin: CoinState

    var body: some View {
        PixelSprite(image: SpriteImage.coin, size: CGSize(width: 16, height: 24))
            .scaleEffect(x: coin.spin, y: 1)
            .opacity(coin.opacity)
            .position(coin.center)
    }
}

/// The 1-1 brick road, tiled at 2pt per pixel and faded out at both ends so it melts into the paper.
private struct BrickRoad: View {
    var body: some View {
        Image(decorative: SpriteImage.brick, scale: 0.5)
            .interpolation(.none)
            .resizable(resizingMode: .tile)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.1),
                        .init(color: .black, location: 0.9),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing)
            }
            .opacity(0.9)
            .allowsHitTesting(false)
    }
}
