import Foundation

enum BlockTone: Equatable {
    /// `pending` is the gold "?" block a key flips into once the code is complete.
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
    /// Light flash on impact, 0...1.
    var flash: Double = 0
    /// How far a green key has turned back into a gold "?" block during the merge, 0...1.
    var gold: Double = 0
    var opacity: Double = 1
    var scale: Double = 1
    /// Vertical squash while the key flips over (1 = face on, ~0 = edge on).
    var flip: Double = 1
    /// Stacking order while the row collapses into a deck (left key on top).
    var zIndex: Double = 0
    /// How much of the check mark has been drawn, 0...1.
    var checkTrim: Double = 1
    /// The big green check key at the end.
    var isHero = false
}

struct CoinState: Identifiable, Equatable {
    var id: Int
    var center: CGPoint
    /// Horizontal squash that fakes the coin spinning.
    var spin: Double
    var opacity: Double
    /// Burst coins fly in front of the keys; hit coins rise from behind them.
    var popsOut = false
}

struct RingState: Identifiable, Equatable {
    var id: Int
    var center: CGPoint
    var scale: Double
    var opacity: Double
}

/// Mario's speech bubble after a miss.
struct SpeechState: Equatable {
    var center: CGPoint
    /// Mario stands to the right of the bubble, so the tail sits on its right.
    var tailOnRight: Bool
    var wrongSlots: [Int]
    var scale: Double
}

struct CastleState: Equatable {
    var center: CGPoint
    var opacity: Double
}

struct HeartState: Equatable {
    var center: CGPoint
    var scale: Double
}

/// Everything the stage needs from the flow model for one frame.
struct StageInput {
    var digits: [Character?]
    var locked: Set<Int>
    var activeSlot: Int?
    var isFocused: Bool
    var restingMario: MarioSpot?
    /// Slots Mario is still telling you to fix, once a miss has been committed.
    var speech: [Int]?
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
    var mario: MarioPose?
    var speech: SpeechState?
    var castle: CastleState?
    var princess: PrincessPose?
    var heart: HeartState?

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
                                     glyph: Self.glyph(digit)))
        }
        let pose = Self.standing(at: input.restingMario ?? layout.startSpot)
        mario = pose
        if let wrong = input.speech {
            speech = Self.speech(beside: pose, wrong: wrong, layout: layout, scale: 1)
        }
    }

    private mutating func buildRunning(_ c: Choreography, input: StageInput, layout: StageLayout) {
        let t = input.time
        let animated = !c.reducedMotion
        let pose = c.marioPose(at: t) ?? Self.standing(at: input.restingMario ?? layout.startSpot)
        mario = pose

        var merge = 0.0
        if case let .verified(mergeStart, _) = c.outcome {
            merge = Motion.clamp((t - mergeStart) / Choreography.mergeDuration)
        }
        let flipOrder = c.hits.map(\.slot).sorted()

        for slot in 0..<StageLayout.slotCount {
            var block = BlockState(id: slot, center: Self.blockCenter(slot, layout),
                                   tone: input.locked.contains(slot) ? .correct : .filled,
                                   glyph: Self.glyph(input.digits[slot]))

            if let hit = c.hit(for: slot) {
                let dt = t - hit.time
                if dt < 0 {
                    // Each key flips over into a ? block, left to right, the moment the code is complete.
                    let order = Double(flipOrder.firstIndex(of: slot) ?? 0)
                    let p = animated ? Motion.clamp((t - 0.06 * order) / 0.24) : 1
                    block.tone = p < 0.5 ? .filled : .pending
                    block.flip = Motion.flip(p)
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
                    let deck = Motion.deck(slot: slot, progress: merge, from: block.center.x, centerX: layout.centerX)
                    block.offset.width += deck.dx
                    block.scale = deck.scale
                    block.zIndex = Double(StageLayout.slotCount - slot)
                    block.gold = Motion.smoothstep(0.35, 1, merge)
                } else {
                    block.opacity = 1 - merge
                }
                block.glyphOpacity = max(0, 1 - merge * 2.5)
                if merge >= 1 { block.opacity = 0 }
            }
            blocks.append(block)
        }

        if case let .retry(reject) = c.outcome, t >= reject {
            let wrong = c.hits.filter { !$0.correct }.map(\.slot)
            speech = Self.speech(beside: pose, wrong: wrong, layout: layout,
                                 scale: animated ? Motion.pop(t - reject) : 1)
        }

        guard case let .verified(mergeStart, reveal) = c.outcome, merge >= 1 || (!animated && merge > 0) else {
            return
        }

        // The merged "?" block, which Mario punches into the check key.
        let center = CGPoint(x: layout.centerX, y: layout.blockCenterY)
        var prize = BlockState(id: Self.prizeID, center: center, tone: .correct, glyph: .question, gold: 1,
                               zIndex: Double(StageLayout.slotCount + 1))
        let dt = t - reveal
        if dt < 0 {
            prize.glyphOpacity = Motion.clamp((t - mergeStart - Choreography.mergeDuration) / 0.15)
            if !animated { prize.opacity = merge }
        } else {
            prize.glyph = .check
            prize.gold = 0
            prize.isHero = true
            prize.flash = max(0, 1 - dt / 0.35)
            if animated {
                prize.scale = 1 + 0.3 * Motion.pop(dt)
                prize.checkTrim = Motion.easeOut(Motion.clamp((dt - 0.05) / 0.32))
                prize.offset = Motion.bump(dt, height: 12)
                rings = Motion.rings(sinceReveal: dt, center: center)
                coins += Motion.coinBurst(sinceReveal: dt, origin: center)
            } else {
                prize.scale = 1.3
            }
        }
        blocks.append(prize)

        if let entrance = c.princess {
            addEnding(entrance, t: t, pose: pose, animated: animated, layout: layout)
        }
    }

    private mutating func addEnding(_ entrance: PrincessEntrance, t: Double, pose: MarioPose,
                                    animated: Bool, layout: StageLayout) {
        let rise = entrance.castleProgress(at: t)
        if rise > 0 {
            let lift = animated ? CGFloat(1 - Motion.easeOut(rise)) * 14 : 0
            castle = CastleState(
                center: CGPoint(x: entrance.castleX,
                                y: layout.groundY - StageLayout.castleSize.height / 2 + lift),
                opacity: rise)
        }
        princess = entrance.pose(at: t)
        let dt = t - entrance.arriveAt
        if dt >= 0 {
            // A heart pops between their heads and floats up a touch.
            let float = animated ? CGFloat(Motion.easeOut(Motion.clamp(dt / 0.6))) * 8 : 8
            heart = HeartState(
                center: CGPoint(x: (pose.x + entrance.toX) / 2, y: layout.groundY - 62 - float),
                scale: animated ? Motion.pop(dt) : 1)
        }
    }

    /// Places the bubble beside Mario's head, on the side with more room.
    static func speech(beside pose: MarioPose, wrong: [Int], layout: StageLayout, scale: Double) -> SpeechState {
        let size = StageLayout.bubbleSize
        let tailOnRight = pose.x > layout.centerX
        let marioTop = layout.groundY - StageLayout.marioSize - pose.lift
        let ideal = tailOnRight ? pose.x - 8 - size.width / 2 : pose.x + 8 + size.width / 2
        let x = min(max(ideal, size.width / 2 + 12), layout.width - size.width / 2 - 12)
        return SpeechState(center: CGPoint(x: x, y: marioTop + 8 - size.height / 2),
                           tailOnRight: tailOnRight, wrongSlots: wrong.sorted(), scale: scale)
    }

    private static func standing(at spot: MarioSpot) -> MarioPose {
        MarioPose(x: spot.x, lift: 0, frame: .stand, facing: spot.facing)
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

    /// Squash for a key turning over: face on at 0 and 1, edge on at 0.5.
    static func flip(_ p: Double) -> Double {
        max(0.04, abs(cos(.pi * p)))
    }

    /// The reference's collapse: the row slides into a fanned deck around the centre (left key on top),
    /// then the fan closes into a single key.
    static func deck(slot: Int, progress: Double, from x: CGFloat, centerX: CGFloat) -> (dx: CGFloat, scale: Double) {
        let gather = easeInOut(clamp(progress / 0.65))
        let close = easeInOut(clamp((progress - 0.65) / 0.35))
        let spread = 8 * CGFloat(1 - close)
        let fanned = centerX + (CGFloat(slot) - CGFloat(StageLayout.slotCount - 1) / 2) * spread
        let scale = 1 - 0.035 * Double(slot) * (1 - close) * gather
        return ((fanned - x) * CGFloat(gather), scale)
    }

    /// Key knocked up and dropping back, like a brick in 1-1.
    static func bump(_ dt: Double, height: Double) -> CGSize {
        guard dt >= 0, dt < 0.2 else { return .zero }
        return CGSize(width: 0, height: -height * sin(.pi * dt / 0.2))
    }

    /// A wrong key barely budges and rattles instead.
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
        let rise = CGFloat(max(0, 1 - arc * arc) * 62)
        let spin = 0.2 + 0.8 * abs(cos(u * 3 * .pi))
        let opacity = u < 0.7 ? 1 : 1 - (u - 0.7) / 0.3
        return (rise, spin, opacity)
    }

    static func rings(sinceReveal dt: Double, center: CGPoint) -> [RingState] {
        (0..<2).compactMap { k -> RingState? in
            let local = dt - Double(k) * 0.16
            guard local >= 0, local < 1.1 else { return nil }
            let p = local / 1.1
            return RingState(id: k, center: center, scale: 1.3 + 1.2 * easeOut(p), opacity: 0.4 * (1 - p))
        }
    }

    /// A fountain of coins out of the check key.
    static func coinBurst(sinceReveal dt: Double, origin: CGPoint) -> [CoinState] {
        guard dt >= 0, dt < 0.95 else { return [] }
        return (0..<8).map { i in
            let r1 = noise(i, 7), r2 = noise(i, 8)
            let angle = -Double.pi / 2 + (Double(i) - 3.5) / 3.5 * 0.95 + (r1 - 0.5) * 0.2
            let speed = 380 + 110 * r2
            let x = Double(origin.x) + cos(angle) * speed * dt
            let y = Double(origin.y) + sin(angle) * speed * dt + 0.5 * 1500 * dt * dt
            return CoinState(id: 100 + i, center: CGPoint(x: x, y: y),
                             spin: 0.2 + 0.8 * abs(cos(dt * 14 + r1 * 6)),
                             opacity: 1 - smoothstep(0.55, 0.95, dt), popsOut: true)
        }
    }

    /// Deterministic 0..<1 noise so the burst looks random but never flickers between frames.
    private static func noise(_ i: Int, _ salt: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43758.5453
        return v - floor(v)
    }
}
