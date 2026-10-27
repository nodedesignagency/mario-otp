import Foundation

/// Geometry of the stage: the row of keycaps, the floor Mario runs on, and the gap between them.
/// Every position the choreography produces lives in this coordinate space (origin = stage top-left).
struct StageLayout: Equatable {
    static let slotCount = 4
    static let blockSize: CGFloat = 64
    static let blockSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 17
    /// Room above the keys for the bump.
    static let topInset: CGFloat = 22
    /// Gap between Mario's head (standing) and the underside of a key — exactly how high a bonk lifts him.
    static let headroom: CGFloat = 60
    static let marioPixel: CGFloat = 3
    static let marioSize: CGFloat = 16 * marioPixel
    /// The brick road Mario runs on.
    static let groundHeight: CGFloat = 16
    static let height: CGFloat = topInset + blockSize + headroom + marioSize + groundHeight
    static let bubbleSize = CGSize(width: 196, height: 62)

    var width: CGFloat

    var pitch: CGFloat { Self.blockSize + Self.blockSpacing }
    var centerX: CGFloat { width / 2 }
    var blockTop: CGFloat { Self.topInset }
    var blockBottom: CGFloat { Self.topInset + Self.blockSize }
    var blockCenterY: CGFloat { Self.topInset + Self.blockSize / 2 }
    /// Top of the road, where Mario's feet are.
    var groundY: CGFloat { blockBottom + Self.headroom + Self.marioSize }

    /// Where Mario waits before his first run: at the take-off point for the first key.
    var startSpot: MarioSpot {
        let jump = BonkJump(contactLift: Self.headroom)
        let takeoff = blockCenterX(0) - Choreography.fistReach - jump.contactFraction * pitch
        return MarioSpot(x: max(Self.marioSize / 2 + 2, takeoff), facing: .right)
    }

    func blockCenterX(_ slot: Int) -> CGFloat {
        centerX + (CGFloat(slot) - CGFloat(Self.slotCount - 1) / 2) * pitch
    }
}
