import SwiftUI

enum Theme {
    static let orange = Color(red: 1.0, green: 0.42, blue: 0.17)
    static let green = Color(red: 0.24, green: 0.88, blue: 0.47)
    static let red = Color(red: 1.0, green: 0.30, blue: 0.30)
    static let blue = Color(red: 0.25, green: 0.50, blue: 1.0)

    static let gold = Color(red: 1.0, green: 0.76, blue: 0.20)
    static let goldLight = Color(red: 1.0, green: 0.88, blue: 0.48)
    static let goldDeep = Color(red: 0.91, green: 0.57, blue: 0.10)
    static let goldEdge = Color(red: 0.55, green: 0.30, blue: 0.04)

    static let blockFill = Color(white: 0.105)
    static let sheetTop = Color(white: 0.125)
    static let sheetBottom = Color(white: 0.085)

    static let confetti: [Color] = [green, gold, .white, red, blue]
}
