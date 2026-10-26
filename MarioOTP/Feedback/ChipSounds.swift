import AVFoundation

/// A tiny 8-bit sound board. Every effect is synthesised once at launch from square, triangle
/// and noise "notes", so there are no audio files to ship (or license).
final class ChipSounds {
    enum Effect: CaseIterable {
        case tap, jump, coin, bump, merge, fanfare, hop, reject
    }

    private let engine = AVAudioEngine()
    private let voices: [AVAudioPlayerNode]
    private var nextVoice = 0
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var sessionConfigured = false

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!
        voices = (0..<4).map { _ in AVAudioPlayerNode() }
        for voice in voices {
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
        }
        engine.mainMixerNode.outputVolume = 0.32
        for effect in Effect.allCases {
            buffers[effect] = Synth.render(effect.notes, format: format)
        }
        engine.prepare()
    }

    func play(_ effect: Effect) {
        guard let buffer = buffers[effect], startIfNeeded() else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.isPlaying {
            voice.play()
        }
    }

    /// Starts lazily, and again after an interruption or route change has stopped the engine.
    private func startIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            if !sessionConfigured {
                // Ambient: mixes with music and respects the silent switch.
                try AVAudioSession.sharedInstance().setCategory(.ambient)
                sessionConfigured = true
            }
            try engine.start()
            return true
        } catch {
            return false
        }
    }
}

struct Note {
    enum Wave {
        case square(duty: Double)
        case triangle
        case noise
    }

    var wave: Wave
    var from: Double
    var to: Double
    var duration: Double
    var volume: Double
    /// Exponential decay rate; 0 holds the note flat until a short release.
    var decay: Double = 0

    static func square(_ frequency: Double, _ duration: Double, volume: Double = 0.3,
                       duty: Double = 0.5, decay: Double = 0) -> Note {
        sweep(frequency, frequency, duration, volume: volume, duty: duty, decay: decay)
    }

    static func sweep(_ from: Double, _ to: Double, _ duration: Double, volume: Double = 0.3,
                      duty: Double = 0.5, decay: Double = 0) -> Note {
        Note(wave: .square(duty: duty), from: from, to: to, duration: duration, volume: volume, decay: decay)
    }
}

private extension ChipSounds.Effect {
    var notes: [Note] {
        switch self {
        case .tap:
            return [Note.square(1760, 0.028, volume: 0.16, duty: 0.25)]
        case .jump:
            return [Note.sweep(280, 840, 0.15, volume: 0.28, duty: 0.25)]
        case .coin:
            return [Note.square(1046.5, 0.06), Note.square(1568, 0.34, decay: 7)]
        case .bump:
            return [Note(wave: .triangle, from: 150, to: 60, duration: 0.1, volume: 0.9),
                    Note(wave: .noise, from: 0, to: 0, duration: 0.05, volume: 0.22, decay: 40)]
        case .merge:
            return [523.25, 659.25, 783.99, 1046.5].map { Note.square($0, 0.05, volume: 0.2) }
        case .fanfare:
            let arpeggio: [Note] = [523.25, 659.25, 783.99].map { Note.square($0, 0.09, volume: 0.24) }
            return arpeggio + [Note.square(1046.5, 0.12, volume: 0.24), Note.square(1318.5, 0.45, volume: 0.24, decay: 4)]
        case .hop:
            return [Note.sweep(400, 700, 0.09, volume: 0.2, duty: 0.25)]
        case .reject:
            return [Note.square(392, 0.12, volume: 0.26), Note.sweep(311.13, 293.66, 0.3, volume: 0.26, decay: 3)]
        }
    }
}

private enum Synth {
    static let sampleRate: Double = 44_100

    static func render(_ notes: [Note], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let total = notes.reduce(0) { $0 + $1.duration }
        let capacity = AVAudioFrameCount(total * sampleRate)
        guard capacity > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity),
              let channel = buffer.floatChannelData?[0]
        else { return nil }

        var index = 0
        var phase = 0.0
        var seed: UInt32 = 0x1234_5678
        for note in notes {
            let count = Int(note.duration * sampleRate)
            for i in 0..<count where index < Int(capacity) {
                let t = Double(i) / sampleRate
                let frequency = note.from + (note.to - note.from) * Double(i) / Double(count)
                phase = (phase + frequency / sampleRate).truncatingRemainder(dividingBy: 1)

                let raw: Double
                switch note.wave {
                case .square(let duty):
                    raw = phase < duty ? 1 : -1
                case .triangle:
                    raw = 4 * abs(phase - 0.5) - 1
                case .noise:
                    seed ^= seed << 13
                    seed ^= seed >> 17
                    seed ^= seed << 5
                    raw = Double(seed) / Double(UInt32.max) * 2 - 1
                }

                let attack = min(1, t / 0.003)
                let release = min(1, (note.duration - t) / 0.012)
                let envelope = note.decay > 0 ? exp(-note.decay * t) : 1
                channel[index] = Float(raw * note.volume * attack * release * envelope)
                index += 1
            }
        }
        buffer.frameLength = AVAudioFrameCount(index)
        return buffer
    }
}
