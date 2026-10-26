import Foundation

enum BlockTone: Equatable {
    case empty, active, filled, pending, correct, wrong
}

enum BlockGlyph: Hashable {
    case blank
    case digit(Character)
    case question
    case check
}

struct BlockState: Identifiable, Equatable {
    var id: Int
    var center: CGPoint
    var offset: CGSize = .zero
    var tone: BlockTone
    var glyph: BlockGlyph
    var glyphOpacity: Double = 1
    /// White flash on impact, 0...1.
    var flash: Double = 0
    /// How far the block has turned into a gold "?" block, 0...1.
    var gold: Double = 0
    /// Multiplier on the tone's glow, used for the waiting pulse.
    var glow: Double = 1
    var opacity: Double = 1
    var showsCaret = false
}

struct CoinState: Identifiable, Equatable {
    var id: Int
    var center: CGPoint
    /// Horizontal squash that fakes the coin spinning.
    var spin: Double
    var opacity: Double
}

struct RingState: Identifiable, Equatable {
    var id: Int
    var center: CGPoint
    var scale: Double
    var opacity: Double
}

struct ConfettiPiece: Equatable {
    var center: CGPoint
    var size: CGFloat
    var rotation: Double
    var palette: Int
    var opacity: Double
}

struct BubbleState: Equatable {
    var center: CGPoint
    var scale: Double
    var opacity: Double
}

/// Everything the stage needs from the flow model for one frame.
struct StageInput {
    var digits: [Character?]
    var locked: Set<Int>
    var activeSlot: Int?
    var isFocused: Bool
    var restingMario: MarioSpot?
    var choreography: Choreography?
    /// Seconds since the choreography started.
    var time: Double
}

/// One frame of the stage, as plain values. Built fresh every frame while a run is playing.
struct StageScene {
    static let prizeID = StageLayout.slotCount

    var blocks: [BlockState] = []
    var coins: [CoinState] = []
    var rings: [RingState] = []
    var confetti: [ConfettiPiece] = []
    var mario: MarioPose?
    var bubble: BubbleState?

    init(input: StageInput, layout: StageLayout) {
        if let choreography = input.choreography {
            buildRunning(choreography, input: input, layout: layout)
        } else {
            buildIdle(input: input, layout: layout)
        }
    }

    private mutating func buildIdle(input: StageInput, layout: StageLayout) {
        for slot in 0..<StageLayout.slotCount {
            let digit = input.digits[slot]
            let tone: BlockTone
            if input.locked.contains(slot) {
                tone = .correct
            } else if digit != nil {
                tone = .filled
            } else if input.isFocused && slot == input.activeSlot {
                tone = .active
            } else {
                tone = .empty
            }
            blocks.append(BlockState(id: slot, center: Self.blockCenter(slot, layout), tone: tone,
                                     glyph: Self.glyph(digit), showsCaret: tone == .active))
        }
        mario = input.restingMario.map { MarioPose(x: $0.x, lift: 0, frame: .stand, facing: $0.facing) }
    }

    private mutating func buildRunning(_ c: Choreography, input: StageInput, layout: StageLayout) {
        let t = input.time
        let animated = !c.reducedMotion
        mario = c.marioPose(at: t)

        var merge = 0.0
        if case let .verified(mergeStart, _) = c.outcome {
            merge = Motion.easeInOut(Motion.clamp((t - mergeStart) / Choreography.mergeDuration))
        }

        for slot in 0..<StageLayout.slotCount {
            var block = BlockState(id: slot, center: Self.blockCenter(slot, layout),
                                   tone: input.locked.contains(slot) ? .correct : .filled,
                                   glyph: Self.glyph(input.digits[slot]))

            if let hit = c.hit(for: slot) {
                let dt = t - hit.time
                if dt < 0 {
                    block.tone = .pending
                    block.glow = 0.7 + 0.3 * sin(t * 9 + Double(slot) * 0.8)
                } else {
                    block.tone = hit.correct ? .correct : .wrong
                    block.flash = max(0, 1 - dt / 0.28)
                    if animated {
                        block.offset = hit.correct ? Motion.bump(dt, height: 10) : Motion.dud(dt)
                        if hit.correct, let coin = Motion.coin(dt) {
                            coins.append(CoinState(
                                id: slot,
                                center: CGPoint(x: block.center.x, y: layout.blockTop + 6 - coin.rise),
                                spin: coin.spin, opacity: coin.opacity))
                        }
                    }
                }
            }

            if case let .retry(reject) = c.outcome, block.tone == .wrong, animated {
                block.offset.width += Motion.shake(t - reject)
            }

            if merge > 0 {
                if animated {
                    block.offset.width += (layout.centerX - block.center.x) * CGFloat(merge)
                    block.offset.height -= CGFloat(sin(merge * .pi)) * 10
                    block.gold = Motion.smoothstep(0.25, 1, merge)
                } else {
                    block.opacity = 1 - merge
                }
                block.glyphOpacity = max(0, 1 - merge * 2.2)
                if merge >= 1 { block.opacity = 0 }
            }
            blocks.append(block)
        }

        guard case let .verified(mergeStart, reveal) = c.outcome, merge >= 1 || (!animated && merge > 0) else {
            addBubble(c, t: t, layout: layout)
            return
        }

        // The merged "?" block, which Mario punches into a check mark.
        let center = CGPoint(x: layout.centerX, y: layout.blockCenterY)
        var prize = BlockState(id: Self.prizeID, center: center, tone: .correct, glyph: .question, gold: 1)
        let dt = t - reveal
        if dt < 0 {
            prize.glyphOpacity = Motion.clamp((t - mergeStart - Choreography.mergeDuration) / 0.15)
            prize.glow = 0.8 + 0.2 * sin(t * 8)
            if !animated { prize.opacity = merge }
        } else {
            prize.glyph = .check
            prize.gold = 0
            prize.flash = max(0, 1 - dt / 0.35)
            if animated {
                prize.offset = Motion.bump(dt, height: 12)
                rings = Motion.rings(sinceReveal: dt, center: center)
                confetti = Motion.confetti(sinceReveal: dt, origin: center)
            }
        }
        blocks.append(prize)
    }

    private mutating func addBubble(_ c: Choreography, t: Double, layout: StageLayout) {
        guard case let .retry(reject) = c.outcome, !c.reducedMotion, let pose = mario else { return }
        let dt = t - reject
        let life = c.commitTime - reject
        guard dt >= 0, dt <= life else { return }
        bubble = BubbleState(
            center: CGPoint(x: pose.x, y: layout.groundY - StageLayout.marioSize - 20 - pose.lift),
            scale: Motion.pop(dt),
            opacity: Motion.clamp((life - dt) / 0.2))
    }

    private static func blockCenter(_ slot: Int, _ layout: StageLayout) -> CGPoint {
        CGPoint(x: layout.blockCenterX(slot), y: layout.blockCenterY)
    }

    private static func glyph(_ digit: Character?) -> BlockGlyph {
        digit.map(BlockGlyph.digit) ?? .blank
    }
}

/// Curves for the stage. All take seconds since the event and return to rest on their own.
enum Motion {
    static let coinLife = 0.62

    static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

    static func easeOut(_ x: Double) -> Double { 1 - (1 - x) * (1 - x) }

    static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let u = clamp((x - edge0) / (edge1 - edge0))
        return u * u * (3 - 2 * u)
    }

    /// Block knocked up and dropping back, like a brick in 1-1.
    static func bump(_ dt: Double, height: Double) -> CGSize {
        guard dt >= 0, dt < 0.2 else { return .zero }
        return CGSize(width: 0, height: -height * sin(.pi * dt / 0.2))
    }

    /// A wrong block barely budges and rattles instead.
    static func dud(_ dt: Double) -> CGSize {
        guard dt >= 0, dt < 0.25 else { return .zero }
        let lift = dt < 0.16 ? -5 * sin(.pi * dt / 0.16) : 0
        return CGSize(width: 3 * sin(dt * 90) * (1 - dt / 0.25), height: lift)
    }

    static func shake(_ dt: Double) -> CGFloat {
        guard dt >= 0, dt < Choreography.shakeDuration else { return 0 }
        return CGFloat(7 * sin(dt * 2 * .pi * 7) * (1 - dt / Choreography.shakeDuration))
    }

    /// Spring from 0 to 1 with a little overshoot.
    static func pop(_ dt: Double) -> Double {
        guard dt > 0 else { return 0 }
        return 1 - exp(-9 * dt) * cos(12 * dt)
    }

    static func coin(_ dt: Double) -> (rise: CGFloat, spin: Double, opacity: Double)? {
        guard dt >= 0, dt <= coinLife else { return nil }
        let u = dt / coinLife
        let arc = (u - 0.45) / 0.45
        let rise = CGFloat(max(0, 1 - arc * arc) * 80)
        let spin = 0.2 + 0.8 * abs(cos(u * 3 * .pi))
        let opacity = u < 0.7 ? 1 : 1 - (u - 0.7) / 0.3
        return (rise, spin, opacity)
    }

    static func rings(sinceReveal dt: Double, center: CGPoint) -> [RingState] {
        var rings: [RingState] = []
        for k in 0..<3 {
            let local = dt - Double(k) * 0.14
            guard local >= 0, local < 1.2 else { continue }
            let p = local / 1.2
            rings.append(RingState(id: k, center: center, scale: 1 + 1.6 * easeOut(p), opacity: 0.55 * (1 - p)))
        }
        // A slow heartbeat once the burst is over.
        let ambient = dt - 1.5
        if ambient >= 0 {
            let p = ambient.truncatingRemainder(dividingBy: 2.6) / 2.0
            if p <= 1 {
                rings.append(RingState(id: 10, center: center, scale: 1 + 1.3 * easeOut(p), opacity: 0.25 * (1 - p)))
            }
        }
        return rings
    }

    static func confetti(sinceReveal dt: Double, origin: CGPoint) -> [ConfettiPiece] {
        guard dt >= 0, dt < 1.4 else { return [] }
        return (0..<26).map { i in
            let r1 = noise(i, 1), r2 = noise(i, 2), r3 = noise(i, 3)
            let angle = -Double.pi / 2 + (r1 - 0.5) * 2.4
            let speed = 240 + 200 * r2
            let x = Double(origin.x) + cos(angle) * speed * dt
            let y = Double(origin.y) + sin(angle) * speed * dt + 0.5 * 900 * dt * dt
            return ConfettiPiece(
                center: CGPoint(x: x, y: y),
                size: 4 + (r3 * 3).rounded(),
                rotation: dt * (4 + 8 * r3) * (r1 > 0.5 ? 1 : -1),
                palette: i % 5,
                opacity: 1 - smoothstep(0.8, 1.4, dt))
        }
    }

    /// Deterministic 0..<1 noise so confetti looks random but never flickers between frames.
    private static func noise(_ i: Int, _ salt: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return v - floor(v)
    }
}
