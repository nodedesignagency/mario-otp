import UIKit

/// Sound + haptics for each beat of the show. Muting silences the sounds; haptics stay on.
@MainActor
final class Feedback {
    var isMuted = false

    private let sounds = ChipSounds()
    private let tapHaptic = UIImpactFeedbackGenerator(style: .light)
    private let bonkHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let dudHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let notifier = UINotificationFeedbackGenerator()

    func keyTap() {
        tapHaptic.impactOccurred(intensity: 0.7)
        play(.tap)
    }

    func jump() {
        bonkHaptic.prepare()
        play(.jump)
    }

    func coin() {
        bonkHaptic.impactOccurred()
        play(.coin)
    }

    func dud() {
        dudHaptic.impactOccurred(intensity: 0.8)
        play(.bump)
    }

    func merge() {
        notifier.prepare()
        play(.merge)
    }

    func reveal() {
        notifier.notificationOccurred(.success)
        play(.fanfare)
    }

    func hop() {
        play(.hop)
    }

    func reject() {
        notifier.notificationOccurred(.error)
        play(.reject)
    }

    private func play(_ effect: ChipSounds.Effect) {
        guard !isMuted else { return }
        sounds.play(effect)
    }
}
