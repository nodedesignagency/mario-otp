import SwiftUI
import Observation

enum Headline: Hashable {
    case prompt
    case resent
    case retry(wrong: Int)
    case verified

    var title: String {
        switch self {
        case .prompt: return "Let’s verify your number"
        case .resent: return "Fresh code, coming up"
        case .retry: return "So close!"
        case .verified: return "Verified successfully"
        }
    }

    var subtitle: String? {
        switch self {
        case .prompt:
            return "We’ve sent a 4-digit code to your phone.\nIt’ll auto-verify once entered."
        case .resent:
            return "We’ve sent you a new 4-digit code.\nIt’ll auto-verify once entered."
        case .retry(let wrong):
            let count = wrong == 1 ? "One digit was" : "\(wrong) digits were"
            return "\(count) off — greens are locked in.\nRetype the empty blocks."
        case .verified:
            return nil
        }
    }
}

/// Stand-in for the real backend. Grades every digit separately so Mario can light each block.
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
    private(set) var demoCode = "1985"
    private(set) var score = 0
    private(set) var coins = 0
    private(set) var world = 1
    private(set) var isMuted = false
    private(set) var resendAvailableAt = Date().addingTimeInterval(OTPFlowModel.resendCooldown)

    /// Reported by the stage once it knows its width.
    @ObservationIgnored var layout: StageLayout?
    @ObservationIgnored var reduceMotion = false
    private let feedback: Feedback
    @ObservationIgnored private var playback: Task<Void, Never>?

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
                   isFocused: isFocused && acceptsInput, restingMario: restingMario,
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
        if grew { feedback.keyTap() }
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
            digits = Array(repeating: nil, count: Self.codeLength)
            locked = []
            headline = .resent
        }
        resendAvailableAt = Date().addingTimeInterval(Self.resendCooldown)
        feedback.hop()
    }

    func playAgain() {
        playback?.cancel()
        withAnimation(.easeInOut(duration: 0.35)) {
            digits = Array(repeating: nil, count: Self.codeLength)
            locked = []
            activeRun = nil
            restingMario = nil
            phase = .entering
            headline = .prompt
            world += 1
        }
        resendAvailableAt = Date().addingTimeInterval(Self.resendCooldown)
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
                withAnimation(.snappy) {
                    coins += 1
                    score += 200
                }
            } else {
                feedback.dud()
            }
        case .merge:
            feedback.merge()
        case .reveal:
            feedback.reveal()
            withAnimation(.snappy) {
                score += 1000
                headline = .verified
            }
            AccessibilityNotification.Announcement(headline.title).post()
        case .hop:
            feedback.hop()
        case .reject:
            feedback.reject()
            headline = .retry(wrong: choreography.hits.filter { !$0.correct }.count)
            let announcement = [headline.title, headline.subtitle ?? ""].joined(separator: " ")
            AccessibilityNotification.Announcement(announcement).post()
        case .commit:
            commit(choreography)
        }
    }

    private func commit(_ choreography: Choreography) {
        restingMario = choreography.marioEnd
        if choreography.succeeds {
            // Keep the run alive so the check block keeps its slow glow pulse.
            phase = .verified
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
            activeRun = nil
            phase = .entering
            world += 1
        }
    }
}
