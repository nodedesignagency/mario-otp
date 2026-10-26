import Foundation

/// Geometry of the stage: the row of OTP blocks, the floor Mario runs on, and the gap between them.
/// Every position the choreography produces lives in this coordinate space (origin = stage top-left).
struct StageLayout: Equatable {
    static let slotCount = 4
    static let blockSize: CGFloat = 60
    static let blockSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 16
    /// Room above the blocks for the bump.
    static let topInset: CGFloat = 22
    /// Gap between Mario's head (standing) and the underside of a block — exactly how high a bonk lifts him.
    static let headroom: CGFloat = 52
    static let marioPixel: CGFloat = 3
    static let marioSize: CGFloat = 16 * marioPixel
    static let groundHeight: CGFloat = 16
    static let height: CGFloat = topInset + blockSize + headroom + marioSize + groundHeight

    var width: CGFloat

    var pitch: CGFloat { Self.blockSize + Self.blockSpacing }
    var centerX: CGFloat { width / 2 }
    var blockTop: CGFloat { Self.topInset }
    var blockBottom: CGFloat { Self.topInset + Self.blockSize }
    var blockCenterY: CGFloat { Self.topInset + Self.blockSize / 2 }
    /// Top edge of the ground strip, i.e. where Mario's feet are.
    var groundY: CGFloat { blockBottom + Self.headroom + Self.marioSize }
    /// Just past the sheet's left edge, where Mario waits before his entrance.
    var offstageLeft: CGFloat { -Self.marioSize }

    func blockCenterX(_ slot: Int) -> CGFloat {
        centerX + (CGFloat(slot) - CGFloat(Self.slotCount - 1) / 2) * pitch
    }
}
