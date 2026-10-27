import SwiftUI

/// What the princess says when she reaches Mario: a different line each time,
/// and a cheekier one if it took a few tries.
struct PrincessQuip: Equatable {
    let greeting: String
    let message: String

    var full: String { greeting + " " + message }

    /// Seconds per letter while it types out.
    static let characterDelay = 0.028

    static let firstTry = [
        PrincessQuip(greeting: "Right castle, Mario!", message: "Your code checks out. Let’s-a go!"),
        PrincessQuip(greeting: "Wahoo! Code accepted!", message: "Not even Bowser could stop that."),
        PrincessQuip(greeting: "It’s-a you!", message: "Identity confirmed. Let’s-a go!"),
    ]

    static let afterMisses = [
        PrincessQuip(greeting: "Took a few castles…", message: "…but your code checks out!"),
        PrincessQuip(greeting: "Mamma mia, finally!", message: "Every digit’s home. Let’s-a go!"),
    ]

    static func pick(afterMisses misses: Int) -> PrincessQuip {
        let pool = misses == 0 ? firstTry : afterMisses
        return pool.randomElement() ?? firstTry[0]
    }
}

/// A retro dialog box under the road, typed out one letter at a time like the end of a game.
struct PrincessDialog: View {
    let quip: PrincessQuip
    let startedAt: Date?
    let isComplete: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PixelSprite(image: SpriteImage.princessPortrait, size: CGSize(width: 40, height: 30))
                .padding(.horizontal, 6)
                .padding(.vertical, 7)
                .background(SteppedRectangle(step: 2, steps: 1).fill(Theme.paper))
            TypedLine(quip: quip, startedAt: startedAt, isComplete: isComplete)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PixelFrame())
        .softShadow(contact: 0.04, ambient: 0.06, radius: 10, y: 4)
        .opacity(startedAt == nil ? 0 : 1)
        .offset(y: startedAt == nil ? 10 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(quip.full)
    }
}

private struct TypedLine: View {
    let quip: PrincessQuip
    /// Nil until she arrives; the box already holds its final size so nothing shifts when typing starts.
    let startedAt: Date?
    /// Set once the last letter's blip has played, so the line always ends complete.
    let isComplete: Bool

    var body: some View {
        if let startedAt, !isComplete {
            // Redraws once per letter, then stops.
            TimelineView(.explicit(letterTimes(from: startedAt))) { context in
                let elapsed = context.date.timeIntervalSince(startedAt)
                let shown = Int((elapsed + 0.001) / PrincessQuip.characterDelay)
                lines(shown: min(max(shown, 0), quip.full.count))
            }
        } else {
            lines(shown: isComplete ? quip.full.count : 0)
        }
    }

    private func lines(shown: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Typed(full: quip.greeting, shown: shown)
                .font(.system(size: 16, weight: .heavy).width(.expanded))
                .foregroundStyle(Theme.ink)
            Typed(full: quip.message, shown: max(0, shown - quip.greeting.count - 1))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink2)
        }
    }

    private func letterTimes(from start: Date) -> [Date] {
        let count = quip.full.count
        // One tick per letter, plus a last one safely after the end.
        return (0...count).map { start.addingTimeInterval(Double($0) * PrincessQuip.characterDelay) }
            + [start.addingTimeInterval(Double(count + 1) * PrincessQuip.characterDelay + 0.05)]
    }
}

/// The full text holds the layout still while the visible prefix grows over it.
private struct Typed: View {
    let full: String
    let shown: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(full).hidden()
            Text(String(full.prefix(shown)))
        }
    }
}
