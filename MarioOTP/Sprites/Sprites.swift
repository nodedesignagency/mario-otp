import Foundation

/// A sprite drawn as text: one character per pixel, `.` for transparent.
struct PixelArt {
    let rows: [String]
    /// Character → 0xRRGGBB.
    let palette: [Character: UInt32]

    var width: Int { rows.first?.count ?? 0 }
    var height: Int { rows.count }
}

/// Hand-drawn 16×16 fan-art plumber, his princess, and the bits of scenery they need.
enum Sprites {
    static let marioPalette: [Character: UInt32] = [
        "R": 0xE4281E, // cap & shirt
        "S": 0xFDBF8E, // skin
        "H": 0x6E3815, // hair, moustache, boots
        "E": 0x1B0E08, // eye
        "B": 0x2F5BE6, // overalls
        "Y": 0xFFD23F, // buttons
        "W": 0xFFFFFF, // gloves
    ]

    static let marioStand = PixelArt(rows: [
        ".....RRRRR......",
        "....RRRRRRRRR...",
        "....HHHSSES.....",
        "...HSHSSSESSS...",
        "...HSHHSSSSHSSS.",
        "...HHSSSSSHHHH..",
        ".....SSSSSSSS...",
        "....RRBRRRB.....",
        "...RRRBRRRBRR...",
        "..RRRRBBBBBRRR..",
        "..WWRBYBBBYBRWW.",
        "..WWWBBBBBBBWWW.",
        "..WWBBBBBBBBBWW.",
        "....BBBB.BBBB...",
        "...HHHH...HHHH..",
        "..HHHHH...HHHHH.",
    ], palette: marioPalette)

    static let marioRun: [PixelArt] = [
        PixelArt(rows: [
            ".....RRRRR......",
            "....RRRRRRRRR...",
            "....HHHSSES.....",
            "...HSHSSSESSS...",
            "...HSHHSSSSHSSS.",
            "...HHSSSSSHHHH..",
            ".....SSSSSSSS...",
            "..WWRRRBBRRW....",
            ".WWWRRRRBBBWWW..",
            ".WW.RRRBYBBBWW..",
            "....BBBBBBBBB...",
            "...BBBBBBBBBBB..",
            "..BBBBB...BBBBH.",
            ".HBBBB.....BHHH.",
            ".HHHH......HHHH.",
            "..HHH...........",
        ], palette: marioPalette),
        PixelArt(rows: [
            ".....RRRRR......",
            "....RRRRRRRRR...",
            "....HHHSSES.....",
            "...HSHSSSESSS...",
            "...HSHHSSSSHSSS.",
            "...HHSSSSSHHHH..",
            ".....SSSSSSSS...",
            "....RRRBRR......",
            "...RRRRBBRWW....",
            "...RRRBBYBWW....",
            "...RRBBBBBB.....",
            "...WWBBBBBB.....",
            "...WWBBBBBB.....",
            "....BBBBHHH.....",
            "....HHHHHHH.....",
            "....HHHH........",
        ], palette: marioPalette),
        PixelArt(rows: [
            ".....RRRRR......",
            "....RRRRRRRRR...",
            "....HHHSSES.....",
            "...HSHSSSESSS...",
            "...HSHHSSSSHSSS.",
            "...HHSSSSSHHHH..",
            ".....SSSSSSSS...",
            "....RRRRBRR.....",
            "...RRRRBBBRR....",
            "...RRWWBYBBR....",
            "...RRWWBBBBB....",
            "....BBBBBBBB....",
            "....BBBB.BBB....",
            "...HHHB..BBB....",
            "...HHHH..HHHH...",
            ".........HHHH...",
        ], palette: marioPalette),
    ]

    /// Fist in the air: the row's top-right glove is what meets the block.
    static let marioJump = PixelArt(rows: [
        ".............WW.",
        ".....RRRRR..WWW.",
        "....RRRRRRRRRWW.",
        "....HHHSSES..RR.",
        "...HSHSSSESSSRR.",
        "...HSHHSSSSHSRR.",
        "...HHSSSSSHHHR..",
        ".....SSSSSSSR...",
        "..WWRRRBBRRRR...",
        ".WWWRRRRBBBR....",
        ".WW.RRRBYBBB.HH.",
        "....BBBBBBBBBHH.",
        "...BBBBBBBBBBHH.",
        "..BBBBBB..BBBH..",
        ".HHBBB..........",
        "HHHH............",
    ], palette: marioPalette)

    static let coin = PixelArt(rows: [
        "..GGGG..",
        ".GYYYYg.",
        "GYWYYOYg",
        "GYWYYOYg",
        "GYWYYOYg",
        "GYWYYOYg",
        "GYWYYOYg",
        "GYWYYOYg",
        "GYYYYOYg",
        "GYYYYYYg",
        ".gYYYYg.",
        "..gggg..",
    ], palette: ["G": 0xFFC428, "g": 0xD68C10, "Y": 0xFFD23F, "W": 0xFFFFFF, "O": 0x7A460A])

    static let question = PixelArt(rows: [
        ".WWWWW..",
        "WWKKKWWK",
        "WWK..WWK",
        ".KK..WWK",
        "....WWKK",
        "...WWKK.",
        "...WWK..",
        "....KK..",
        "...WW...",
        "...WWK..",
        "....KK..",
    ], palette: ["W": 0xFFFFFF, "K": 0x281604])

    /// Speech-bubble tail pointing down and right. Its top row sits on the bubble's bottom border and opens it.
    static let bubbleTail = PixelArt(rows: [
        "KWWWK",
        ".KWWK",
        "..KWK",
        "...KK",
        "....K",
    ], palette: ["K": 0x1C1D26, "W": 0xFFFFFF])

    static let princessPalette: [Character: UInt32] = [
        "G": 0xFFC234, // crown
        "J": 0x3D7BFF, // jewels
        "A": 0xFFD54A, // hair
        "a": 0xD6A028, // hair shade
        "S": 0xFDBF8E, // skin
        "E": 0x1B0E08, // eye
        "Q": 0xEE4A33, // lips
        "P": 0xFF8FC8, // dress
        "p": 0xE2559B, // dress shade
        "W": 0xFFFFFF, // gloves
        "D": 0x3C3630, // shoes
    ]

    /// Fan-art princess, 16×24 so she stands a head taller than Mario.
    static let princess = PixelArt(rows: [
        ".......GJG......",
        "......GGGGG.....",
        ".....AAAAAAA....",
        "....AAAAAAAAA...",
        "....AAASSSSAA...",
        "...AAASSESSSA...",
        "...AAASSESSSS...",
        "...AAASSSSSSSS..",
        "...AAAASSQQS....",
        "...AAAAASSS.....",
        "...AAAAA.SS.....",
        "...AAAppPPpp....",
        "..AAAppPJPPpp...",
        "..AAAppPPPPpp...",
        "...aaWPPPPPPW...",
        "....WPPPPPPPW...",
        "....PPPPPPPP....",
        "...PPPPPPPPPP...",
        "...PPPPPPPPPP...",
        "..PPPpPPPPpPPP..",
        "..PPpPPPPPPpPP..",
        ".PPPpPPPPPPPpPP.",
        ".PPpppppppppppP.",
        "...DD......DD...",
    ], palette: princessPalette)

    static let princessStep = PixelArt(rows: [
        ".......GJG......",
        "......GGGGG.....",
        ".....AAAAAAA....",
        "....AAAAAAAAA...",
        "....AAASSSSAA...",
        "...AAASSESSSA...",
        "...AAASSESSSS...",
        "...AAASSSSSSSS..",
        "...AAAASSQQS....",
        "...AAAAASSS.....",
        "...AAAAA.SS.....",
        "...AAAppPPpp....",
        "..AAAppPJPPpp...",
        "..AAAppPPPPpp...",
        "...aaWPPPPPPW...",
        "....WPPPPPPPW...",
        "....PPPPPPPPP...",
        "...PPPPPPPPPPP..",
        "...PPpPPPPPpPPP.",
        "..PPpPPPPPPPpPP.",
        "..PPpPPPPPPPPpPP",
        "..PpppppppppppP.",
        ".PPppppppppppP..",
        "....DD......DD..",
    ], palette: princessPalette)

    /// Her head and shoulders, for the dialog box.
    static let princessPortrait = PixelArt(rows: Array(princess.rows.prefix(12)), palette: princessPalette)

    /// The 1-1 castle, in the same bricks as the road.
    static let castle = PixelArt(rows: [
        "......LL..LL..LL........",
        "......oo..oo..oo........",
        "......LLLLLMLLLLLM......",
        "......oooooMoooooM......",
        "......oooooDDooooM......",
        "......MMMMMDDMMMMM......",
        "......LLMLLDDLMLLL......",
        "......ooMoooooMooo......",
        "LL..LLooMoooooMooo..LL..",
        "oo..ooMMMMMMMMMMMM..oo..",
        "LLLLLMLLLLLMLLLLLMLLLLLM",
        "oooooMoooooMoooooMoooooM",
        "oooooMoooooMoooooMoooooM",
        "MMMMMMMMMMDDDDMMMMMMMMMM",
        "LLMLLLLLMDDDDDDLLLLLMLLL",
        "ooMoooooMDDDDDDoooooMooo",
        "ooMoooooMDDDDDDoooooMooo",
        "MMMMMMMMMDDDDDDMMMMMMMMM",
        "LLLLLMLLLDDDDDDLLMLLLLLM",
        "oooooMoooDDDDDDooMoooooM",
    ], palette: ["L": 0xE8824A, "o": 0xB4531E, "M": 0x5A2A10, "D": 0x2A1E18])

    static let heart = PixelArt(rows: [
        ".QQ.QQ.",
        "QWQQQQQ",
        "QQQQQQQ",
        "QQQQQQQ",
        ".QQQQQ.",
        "..QQQ..",
        "...Q...",
    ], palette: ["Q": 0xEE4A33, "W": 0xFFFFFF])

    /// One tile of the brick road.
    static let brick = PixelArt(rows: [
        "LLLLLLLM",
        "LooooooM",
        "LooooooM",
        "MMMMMMMM",
        "LLLMLLLL",
        "oooMLooo",
        "oooMLooo",
        "MMMMMMMM",
    ], palette: ["L": 0xE8824A, "o": 0xB4531E, "M": 0x5A2A10])

    static var all: [PixelArt] {
        [marioStand, marioJump, coin, question, bubbleTail, brick,
         princess, princessStep, princessPortrait, castle, heart] + marioRun
    }
}
