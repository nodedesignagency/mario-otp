import SwiftUI

extension PixelArt {
    func makeImage() -> CGImage {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for (y, row) in rows.enumerated() {
            for (x, symbol) in row.enumerated() {
                guard let rgb = palette[symbol] else { continue }
                let i = (y * width + x) * 4
                bytes[i] = UInt8((rgb >> 16) & 0xFF)
                bytes[i + 1] = UInt8((rgb >> 8) & 0xFF)
                bytes[i + 2] = UInt8(rgb & 0xFF)
                bytes[i + 3] = 0xFF
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }
}

/// Sprites rasterised once, on first use.
enum SpriteImage {
    static let stand = Sprites.marioStand.makeImage()
    static let run = Sprites.marioRun.map { $0.makeImage() }
    static let jump = Sprites.marioJump.makeImage()
    static let coin = Sprites.coin.makeImage()
    static let question = Sprites.question.makeImage()
    static let bubbleTail = Sprites.bubbleTail.makeImage()
    static let brick = Sprites.brick.makeImage()
    static let princess = Sprites.princess.makeImage()
    static let princessStep = Sprites.princessStep.makeImage()
    static let princessPortrait = Sprites.princessPortrait.makeImage()
    static let castle = Sprites.castle.makeImage()
    static let heart = Sprites.heart.makeImage()

    static func mario(_ frame: MarioFrame) -> CGImage {
        switch frame {
        case .stand: return stand
        case .run(let step): return run[step % run.count]
        case .jump: return jump
        }
    }
}

/// Draws a sprite with hard pixel edges at any size.
struct PixelSprite: View {
    let image: CGImage
    let size: CGSize

    var body: some View {
        Image(decorative: image, scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(width: size.width, height: size.height)
    }
}
