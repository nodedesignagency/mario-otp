import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Pixel × Paper: warm paper, navy ink, and the three colours Mario lives in.
enum Theme {
    static let paper = Color(hex: 0xF6F3EC)
    static let paperDot = Color(hex: 0xE4DFD3)
    static let card = Color.white
    static let ink = Color(hex: 0x1C1D26)
    static let ink2 = Color(hex: 0x6E6B63)
    static let ink3 = Color(hex: 0xA9A59B)
    static let line = Color(hex: 0xE3DED2)
    /// Warm brown used for shadows, so they sit on the paper instead of greying it.
    static let shadow = Color(hex: 0x3C2A0A)

    static let blue = Color(hex: 0x3D6BFF)

    static let gold = Color(hex: 0xFFC234)
    static let goldLight = Color(hex: 0xFFE37E)
    static let goldSkirt = Color(hex: 0xD6950F)
    static let goldRivet = Color(hex: 0xB97A00)
    static let goldInk = Color(hex: 0x9C5C00)

    static let green = Color(hex: 0x1FA866)
    static let greenLight = Color(hex: 0x3FD08A)
    static let greenSkirt = Color(hex: 0x168352)
    static let greenFace = Color(hex: 0xDCF5E8)
    static let greenFaceTop = Color(hex: 0xEFFBF4)

    static let red = Color(hex: 0xEE4A33)
    static let redSkirt = Color(hex: 0xC93622)
    static let redFace = Color(hex: 0xFDE2DB)
    static let redFaceTop = Color(hex: 0xFFF2EE)

    static let keySkirt = Color(hex: 0xE3DDD0)
    static let keyFaceTop = Color.white
    static let keyFaceBottom = Color(hex: 0xF8F6F1)

    static let pillTop = Color(hex: 0x2C2E3B)
    static let pillBottom = Color(hex: 0x15161E)
}
