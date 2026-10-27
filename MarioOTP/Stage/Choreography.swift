import Foundation

enum Facing: Equatable {
    case left, right

    var sign: CGFloat { self == .right ? 1 : -1 }

    init(toward target: CGFloat, from x: CGFloat) {
        self = target >= x ? .right : .left
    }
}

enum MarioFrame: Equatable {
    case stand
    case run(Int)
    /// The signature jump: fist up, one knee forward.
    case jump
}

struct MarioPose: Equatable {
    var x: CGFloat
    /// Height of Mario's feet above the ground.
    var lift: CGFloat
    var frame: MarioFrame
    var facing: Facing
}

/// Where Mario idles between runs.
struct MarioSpot: Equatable {
    var x: CGFloat
    var facing: Facing
}

/// A hop that punches a block from below. Mario takes off as if aiming above the block, stops dead
/// when his fist meets it, then falls back under the same gravity — the classic NES bonk.
struct BonkJump: Equatable {
    static let overshoot = 1.35
    static let riseToPeak = 0.32

    var contactLift: CGFloat

    var contactTime: Double { Self.riseToPeak * (1 - (1 - 1 / Self.overshoot).squareRoot()) }
    var fallTime: Double { Self.riseToPeak * (1 / Self.overshoot).squareRoot() }
    var duration: Double { contactTime + fallTime }
    var contactFraction: CGFloat { CGFloat(contactTime / duration) }

    func lift(at t: Double) -> CGFloat {
        guard t > 0 else { return 0 }
        if t < contactTime {
            let u = t / Self.riseToPeak
            return contactLift * CGFloat(Self.overshoot * (1 - (1 - u) * (1 - u)))
        }
        let s = min((t - contactTime) / fallTime, 1)
        return contactLift * CGFloat(1 - s * s)
    }
}

struct MarioMove: Equatable {
    enum Kind: Equatable {
        case stand(x: CGFloat, facing: Facing)
        case run(from: CGFloat, to: CGFloat)
        case bonk(from: CGFloat, to: CGFloat, facing: Facing, jump: BonkJump)
        case hop(x: CGFloat, facing: Facing, height: CGFloat)
    }

    var start: Double
    var duration: Double
    var kind: Kind

    func pose(at local: Double) -> MarioPose {
        let p = duration > 0 ? min(max(local / duration, 0), 1) : 1
        switch kind {
        case let .stand(x, facing):
            return MarioPose(x: x, lift: 0, frame: .stand, facing: facing)
        case let .run(from, to):
            let x = from + (to - from) * CGFloat(p)
            let step = Int(abs(x - from) / Choreography.strideLength) % 3
            return MarioPose(x: x, lift: 0, frame: p < 1 ? .run(step) : .stand,
                             facing: Facing(toward: to, from: from))
        case let .bonk(from, to, facing, jump):
            let x = from + (to - from) * CGFloat(p)
            return MarioPose(x: x, lift: jump.lift(at: local), frame: p < 1 ? .jump : .stand, facing: facing)
        case let .hop(x, facing, height):
            let lift = height * CGFloat(4 * p * (1 - p))
            return MarioPose(x: x, lift: lift, frame: p > 0 && p < 1 ? .jump : .stand, facing: facing)
        }
    }
}

/// The whole verification performance, worked out up front: where Mario is at every instant,
/// when each block gets punched, and how the run ends. The stage renders it as a pure function
/// of time, and the flow model fires sounds, haptics and state changes at the cue times.
struct Choreography: Equatable {
    struct Target: Equatable {
        var slot: Int
        var correct: Bool
    }

    struct Hit: Equatable {
        var slot: Int
        var time: Double
        var correct: Bool
    }

    enum Outcome: Equatable {
        /// Blocks merge into a "?" block at `mergeStart`; Mario punches it into a check mark at `reveal`.
        case verified(mergeStart: Double, reveal: Double)
        /// Red blocks shake at `reject`, then get cleared for another try.
        case retry(reject: Double)
    }

    enum Cue: Equatable {
        case jump
        case hit(slot: Int, correct: Bool)
        case merge
        case reveal
        case hop
        case castle
        case princess
        case reject
        case commit
    }

    struct TimedCue: Equatable {
        var time: Double
        var cue: Cue
    }

    static let runSpeed: CGFloat = 440
    static let strideLength: CGFloat = 9
    /// How far ahead of Mario's centre his raised fist is.
    static let fistReach: CGFloat = 15
    static let mergeDuration = 0.55
    static let shakeDuration = 0.45

    var moves: [MarioMove]
    var hits: [Hit]
    var outcome: Outcome
    var cues: [TimedCue]
    var commitTime: Double
    var marioEnd: MarioSpot?
    /// The ending after a verified code: castle, princess, heart.
    var princess: PrincessEntrance?
    var reducedMotion: Bool

    var succeeds: Bool {
        if case .verified = outcome { return true }
        return false
    }

    func hit(for slot: Int) -> Hit? {
        hits.first { $0.slot == slot }
    }

    func marioPose(at t: Double) -> MarioPose? {
        guard let first = moves.first else { return nil }
        guard let move = moves.last(where: { $0.start <= t }) else { return first.pose(at: 0) }
        return move.pose(at: t - move.start)
    }
}

extension Choreography {
    static func make(layout: StageLayout, targets: [Target], mario spot: MarioSpot?, reducedMotion: Bool) -> Choreography {
        reducedMotion
            ? still(layout: layout, targets: targets, spot: spot)
            : animated(layout: layout, targets: targets, spot: spot)
    }

    private static func animated(layout: StageLayout, targets: [Target], spot: MarioSpot?) -> Choreography {
        let jump = BonkJump(contactLift: StageLayout.headroom)
        var track = Track(spot: spot ?? layout.startSpot)
        // Sweep across the row starting from whichever end Mario is nearer.
        let heading: Facing = track.x > layout.centerX ? .left : .right
        let ordered = targets.sorted { heading == .right ? $0.slot < $1.slot : $0.slot > $1.slot }

        // Give the keys a moment to flip over into ? blocks before the first punch.
        track.stand(for: 0.28)
        var hits: [Hit] = []
        for target in ordered {
            let contact = track.bonk(under: layout.blockCenterX(target.slot), heading: heading,
                                     span: layout.pitch, jump: jump)
            hits.append(Hit(slot: target.slot, time: contact, correct: target.correct))
            track.cue(.hit(slot: target.slot, correct: target.correct), at: contact)
        }

        let outcome: Outcome
        var princess: PrincessEntrance?
        if targets.allSatisfy(\.correct) {
            track.stand(for: 0.1)
            let mergeStart = track.time
            track.cue(.merge, at: mergeStart)
            let center = layout.centerX
            let toward = Facing(toward: center, from: track.x)
            track.run(to: center - toward.sign * fistReach)
            track.stand(until: mergeStart + mergeDuration)
            let reveal = track.bonk(under: center, heading: toward, span: 0, jump: jump)
            track.cue(.reveal, at: reveal)
            track.stand(for: 0.2)
            track.hop(height: 22, duration: 0.34)
            track.stand(for: 0.15)
            outcome = .verified(mergeStart: mergeStart, reveal: reveal)

            // A castle rises at the end of the road and the princess hurries over during the victory hop.
            let entrance = PrincessEntrance.walking(to: track.x, layout: layout,
                                                    castleAt: reveal + 0.25, appearAt: reveal + 0.55)
            track.cue(.castle, at: entrance.castleAt)
            track.stand(until: entrance.arriveAt - 0.2)
            track.face(Facing(toward: entrance.toX, from: track.x))
            track.stand(until: entrance.arriveAt + 0.25)
            track.cue(.princess, at: entrance.arriveAt)
            princess = entrance
        } else {
            track.stand(for: 0.08)
            let reject = track.time
            track.cue(.reject, at: reject)
            track.stand(for: 0.8)
            outcome = .retry(reject: reject)
        }
        track.cue(.commit, at: track.time)

        return Choreography(
            moves: track.moves,
            hits: hits,
            outcome: outcome,
            cues: track.cues.sorted { $0.time < $1.time },
            commitTime: track.time,
            marioEnd: MarioSpot(x: track.x, facing: track.facing),
            princess: princess,
            reducedMotion: false
        )
    }

    /// Reduce Motion: no Mario run, keys simply light up one after another.
    private static func still(layout: StageLayout, targets: [Target], spot: MarioSpot?) -> Choreography {
        var cues: [TimedCue] = []
        var hits: [Hit] = []
        var time = 0.2
        for target in targets.sorted(by: { $0.slot < $1.slot }) {
            hits.append(Hit(slot: target.slot, time: time, correct: target.correct))
            cues.append(TimedCue(time: time, cue: .hit(slot: target.slot, correct: target.correct)))
            time += 0.16
        }

        let outcome: Outcome
        var princess: PrincessEntrance?
        if targets.allSatisfy(\.correct) {
            let mergeStart = time + 0.1
            let reveal = mergeStart + mergeDuration + 0.05
            cues.append(TimedCue(time: mergeStart, cue: .merge))
            cues.append(TimedCue(time: reveal, cue: .reveal))
            // She simply appears beside Mario.
            let marioX = (spot ?? layout.startSpot).x
            let entrance = PrincessEntrance(castleAt: reveal, appearAt: reveal + 0.3,
                                            fromX: marioX + PrincessEntrance.standOff,
                                            toX: marioX + PrincessEntrance.standOff,
                                            arriveAt: reveal + 0.3, castleX: layout.castleX)
            cues.append(TimedCue(time: entrance.castleAt, cue: .castle))
            cues.append(TimedCue(time: entrance.arriveAt, cue: .princess))
            princess = entrance
            time = entrance.arriveAt + 0.3
            outcome = .verified(mergeStart: mergeStart, reveal: reveal)
        } else {
            let reject = time + 0.05
            cues.append(TimedCue(time: reject, cue: .reject))
            time = reject + 0.7
            outcome = .retry(reject: reject)
        }
        cues.append(TimedCue(time: time, cue: .commit))

        let moves = spot.map { [MarioMove(start: 0, duration: time, kind: .stand(x: $0.x, facing: $0.facing))] } ?? []
        return Choreography(moves: moves, hits: hits, outcome: outcome, cues: cues,
                            commitTime: time, marioEnd: spot, princess: princess, reducedMotion: true)
    }
}

struct PrincessPose: Equatable {
    var x: CGFloat
    /// Alternates the two walking frames.
    var isStepping: Bool
    var facing: Facing
    var opacity: Double
}

/// The princess walks out of a castle at the end of the road and stops beside Mario.
/// She always comes from the right, so she always faces left, towards him.
struct PrincessEntrance: Equatable {
    static let walkSpeed: CGFloat = 150
    static let strideLength: CGFloat = 8
    /// How far to Mario's right she stops.
    static let standOff: CGFloat = 46
    static let castleRise = 0.35

    var castleAt: Double
    var appearAt: Double
    var fromX: CGFloat
    var toX: CGFloat
    var arriveAt: Double
    var castleX: CGFloat

    static func walking(to marioX: CGFloat, layout: StageLayout, castleAt: Double, appearAt: Double) -> PrincessEntrance {
        let door = layout.castleX
        let stop = min(marioX + standOff, door - 20)
        let walk = Double(abs(door - stop) / walkSpeed)
        return PrincessEntrance(castleAt: castleAt, appearAt: appearAt, fromX: door, toX: stop,
                                arriveAt: appearAt + walk, castleX: door)
    }

    func castleProgress(at t: Double) -> Double {
        min(max((t - castleAt) / Self.castleRise, 0), 1)
    }

    func pose(at t: Double) -> PrincessPose? {
        guard t >= appearAt else { return nil }
        let walk = arriveAt - appearAt
        let p = walk > 0 ? min((t - appearAt) / walk, 1) : 1
        let x = fromX + (toX - fromX) * CGFloat(p)
        let step = Int(abs(x - fromX) / Self.strideLength) % 2 == 1
        return PrincessPose(x: x, isStepping: p < 1 && step, facing: .left,
                            opacity: min((t - appearAt) / 0.18, 1))
    }
}

/// Appends Mario's moves back to back while tracking where he is and which way he faces.
private struct Track {
    var moves: [MarioMove] = []
    var cues: [Choreography.TimedCue] = []
    var time: Double = 0
    var x: CGFloat
    var facing: Facing

    init(spot: MarioSpot) {
        x = spot.x
        facing = spot.facing
    }

    mutating func cue(_ cue: Choreography.Cue, at time: Double) {
        cues.append(Choreography.TimedCue(time: time, cue: cue))
    }

    mutating func stand(for duration: Double) {
        guard duration > 0 else { return }
        append(.stand(x: x, facing: facing), duration: duration)
    }

    mutating func stand(until t: Double) {
        stand(for: t - time)
    }

    /// Turns on the spot; takes effect from the next move.
    mutating func face(_ direction: Facing) {
        facing = direction
    }

    mutating func run(to target: CGFloat) {
        let distance = abs(target - x)
        guard distance >= 1 else { return }
        append(.run(from: x, to: target), duration: Double(distance / Choreography.runSpeed))
        facing = Facing(toward: target, from: x)
        x = target
    }

    /// Runs to the take-off point, then hops so the raised fist meets the underside of the block
    /// centred on `blockX`, carrying on `span` points in the `heading` direction. Returns the moment of contact.
    mutating func bonk(under blockX: CGFloat, heading: Facing, span: CGFloat, jump: BonkJump) -> Double {
        let contactX = blockX - heading.sign * Choreography.fistReach
        var takeoff = contactX - heading.sign * jump.contactFraction * span
        // Not worth turning around for a few points: take off from where he stands.
        if abs(takeoff - x) < 10 { takeoff = x }
        run(to: takeoff)

        let landing = contactX + heading.sign * (1 - jump.contactFraction) * span
        cue(.jump, at: time)
        let contact = time + jump.contactTime
        append(.bonk(from: x, to: landing, facing: heading, jump: jump), duration: jump.duration)
        x = landing
        facing = heading
        return contact
    }

    mutating func hop(height: CGFloat, duration: Double) {
        cue(.hop, at: time)
        append(.hop(x: x, facing: facing, height: height), duration: duration)
    }

    private mutating func append(_ kind: MarioMove.Kind, duration: Double) {
        moves.append(MarioMove(start: time, duration: duration, kind: kind))
        time += duration
    }
}
