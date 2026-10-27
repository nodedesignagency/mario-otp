import SwiftUI
import Observation

enum Headline: Hashable {
    case prompt
    case resent
    case retry
    case verified

    var title: String {
        switch self {
        case .prompt: return "Let’s verify your number"
        case .resent: return "Fresh code sent"
        case .retry: return "So close!"
        case .verified: return "Verified"
        }
    }

    var subtitle: String {
        switch self {
        case .prompt: return "We sent a 4-digit code to •••• 4821.\nIt verifies on its own once entered."
        case .resent: return "A new 4-digit code is on its way.\nIt verifies on its own once entered."
        case .retry: return "Greens are right and stay locked.\nRetype the red ones."
        case .verified: return "You’re in."
        }
    }
}

/// Stand-in for the real backend. Grades every digit separately so Mario can light each key.
enum CodeVerifier {
    static func check(_ entered: [Character], against code: String) -> [Bool] {
        zip(entered, code).map { $0 == $1 }
    }

    static func randomCode(length: Int) -> String {
        String((0..<length).map { _ in Character(String(Int.random(in: 0...9))) })
    }
}

@MainActor
@Observable
final class OTPFlowModel {
    enum Phase: Equatable {
        case entering, checking, verified
    }

    struct ActiveRun {
        let start: Date
        let choreography: Choreography
    }

    static let codeLength = StageLayout.slotCount
    static let resendCooldown: TimeInterval = 30

    private(set) var digits: [Character?] = Array(repeating: nil, count: OTPFlowModel.codeLength)
    /// Slots already confirmed correct; they stay green and are skipped when typing.
    private(set) var locked: Set<Int> = []
    private(set) var phase: Phase = .entering
    private(set) var headline: Headline = .prompt
    private(set) var activeRun: ActiveRun?
    private(set) var restingMario: MarioSpot?
    /// Slots Mario is pointing at after a miss, until you start typing again.
    private(set) var speech: [Int]?
    private(set) var demoCode = "1985"
    private(set) var isMuted = false
    private(set) var resendAvailableAt = Date().addingTimeInterval(OTPFlowModel.resendCooldown)
    /// The finale has finished moving, so the stage can stop redrawing every frame.
    private(set) var isStageSettled = false
    /// When the princess started typing her line, once she's reached Mario.
    private(set) var dialogStartedAt: Date?

    /// Reported by the stage once it knows its width.
    @ObservationIgnored var layout: StageLayout?
    @ObservationIgnored var reduceMotion = false
    private let feedback: Feedback
    @ObservationIgnored private var playback: Task<Void, Never>?
    @ObservationIgnored private var typing: Task<Void, Never>?

    init() {
        feedback = Feedback()
    }

    var acceptsInput: Bool { phase == .entering }

    var editableSlots: [Int] {
        (0..<Self.codeLength).filter { !locked.contains($0) }
    }

    /// What the hidden text field should contain: the digits typed into unlocked slots.
    var entryText: String {
        String(editableSlots.compactMap { digits[$0] })
    }

    var activeSlot: Int? {
        editableSlots.first { digits[$0] == nil }
    }

    func stageInput(time: Double, isFocused: Bool) -> StageInput {
        StageInput(digits: digits, locked: locked, activeSlot: activeSlot,
                   isFocused: isFocused && acceptsInput, restingMario: restingMario, speech: speech,
                   choreography: activeRun?.choreography, time: time)
    }

    func updateEntry(_ text: String) {
        guard acceptsInput else { return }
        let slots = editableSlots
        let typed = Array(text.filter { $0.isASCII && $0.isNumber }.prefix(slots.count))
        var next = digits
        for (offset, slot) in slots.enumerated() {
            next[slot] = offset < typed.count ? typed[offset] : nil
        }
        guard next != digits else { return }

        let grew = next.compactMap { $0 }.count > digits.compactMap { $0 }.count
        digits = next
        if grew {
            feedback.keyTap()
            if speech != nil {
                withAnimation(.easeOut(duration: 0.2)) { speech = nil }
            }
        }
        if typed.count == slots.count { startVerification() }
    }

    func toggleMute() {
        isMuted.toggle()
        feedback.isMuted = isMuted
    }

    func resend() {
        guard acceptsInput, Date() >= resendAvailableAt else { return }
        demoCode = CodeVerifier.randomCode(length: Self.codeLength)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            clearRound()
            headline = .resent
        }
        resendAvailableAt = Date().addingTimeInterval(Self.resendCooldown)
        feedback.hop()
    }

    /// Back to an empty code. Mario stays wherever he is.
    func startOver() {
        guard phase != .checking else { return }
        playback?.cancel()
        withAnimation(.easeInOut(duration: 0.35)) {
            clearRound()
            activeRun = nil
            isStageSettled = false
            phase = .entering
            headline = .prompt
        }
        resendAvailableAt = Date().addingTimeInterval(Self.resendCooldown)
    }

    private func clearRound() {
        digits = Array(repeating: nil, count: Self.codeLength)
        locked = []
        speech = nil
        dialogStartedAt = nil
        typing?.cancel()
    }

    // MARK: - The run

    private func startVerification() {
        guard let layout else { return }
        let entered = digits.compactMap { $0 }
        guard entered.count == Self.codeLength else { return }

        let results = CodeVerifier.check(entered, against: demoCode)
        let targets = editableSlots.map { Choreography.Target(slot: $0, correct: results[$0]) }
        let choreography = Choreography.make(layout: layout, targets: targets,
                                             mario: restingMario, reducedMotion: reduceMotion)
        let start = Date()
        speech = nil
        isStageSettled = false
        phase = .checking
        activeRun = ActiveRun(start: start, choreography: choreography)

        playback?.cancel()
        playback = Task { [weak self] in
            await self?.play(choreography, startedAt: start)
        }
    }

    private func play(_ choreography: Choreography, startedAt start: Date) async {
        for timed in choreography.cues {
            let wait = timed.time - Date().timeIntervalSince(start)
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            perform(timed.cue, in: choreography)
        }
    }

    private func perform(_ cue: Choreography.Cue, in choreography: Choreography) {
        switch cue {
        case .jump:
            feedback.jump()
        case let .hit(_, correct):
            if correct {
                feedback.coin()
            } else {
                feedback.dud()
            }
        case .merge:
            feedback.merge()
        case .reveal:
            feedback.reveal()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                headline = .verified
            }
            AccessibilityNotification.Announcement(headline.title).post()
        case .hop:
            feedback.hop()
        case .castle:
            feedback.castle()
        case .princess:
            feedback.heart()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                dialogStartedAt = Date()
            }
            typeOutPrincessLine()
            AccessibilityNotification.Announcement(PrincessLine.full).post()
        case .reject:
            feedback.reject()
            headline = .retry
            let wrong = choreography.hits.filter { !$0.correct }.map { String($0.slot + 1) }
            let announcement = "So close. Fix digits " + wrong.joined(separator: ", ") + "."
            AccessibilityNotification.Announcement(announcement).post()
        case .commit:
            commit(choreography)
        }
    }

    /// A blip every other letter while the dialog box types her line.
    private func typeOutPrincessLine() {
        typing?.cancel()
        typing = Task { [weak self] in
            for index in 0..<PrincessLine.full.count {
                try? await Task.sleep(for: .seconds(PrincessLine.characterDelay))
                guard !Task.isCancelled else { return }
                if index % 2 == 0 { self?.feedback.blip() }
            }
        }
    }

    private func commit(_ choreography: Choreography) {
        restingMario = choreography.marioEnd
        if choreography.succeeds {
            // Keep the run alive so the check key stays on stage, and let the rings finish before pausing.
            phase = .verified
            playback = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.6))
                guard !Task.isCancelled, self?.phase == .verified else { return }
                self?.isStageSettled = true
            }
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            for hit in choreography.hits {
                if hit.correct {
                    locked.insert(hit.slot)
                } else {
                    digits[hit.slot] = nil
                }
            }
            speech = choreography.hits.filter { !$0.correct }.map(\.slot)
            activeRun = nil
            phase = .entering
        }
    }
}
