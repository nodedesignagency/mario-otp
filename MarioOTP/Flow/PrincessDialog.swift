import SwiftUI

/// What the princess says once she reaches Mario.
enum PrincessLine {
    static let greeting = "Thank you, Mario!"
    static let message = "Your number is verified."
    static var full: String { greeting + " " + message }
    /// Seconds per letter while it types out.
    static let characterDelay = 0.035
}

/// A retro dialog box under the road, typed out one letter at a time like the end of a game.
struct PrincessDialog: View {
    let startedAt: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PixelSprite(image: SpriteImage.princessPortrait, size: CGSize(width: 40, height: 30))
                .padding(.horizontal, 6)
                .padding(.vertical, 7)
                .background(SteppedRectangle(step: 2, steps: 1).fill(Theme.paper))
            TypedLine(startedAt: startedAt)
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
        .accessibilityLabel(PrincessLine.full)
    }
}

private struct TypedLine: View {
    /// Nil until she arrives; the box already holds its final size so nothing shifts when typing starts.
    let startedAt: Date?

    var body: some View {
        if let startedAt {
            // Redraws exactly once per letter, then stops.
            TimelineView(.explicit(Self.letterTimes(from: startedAt))) { context in
                let elapsed = context.date.timeIntervalSince(startedAt)
                lines(shown: min(max(Int(elapsed / PrincessLine.characterDelay), 0), PrincessLine.full.count))
            }
        } else {
            lines(shown: 0)
        }
    }

    private func lines(shown: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Typed(full: PrincessLine.greeting, shown: shown)
                .font(.system(size: 17, weight: .heavy).width(.expanded))
                .foregroundStyle(Theme.ink)
            Typed(full: PrincessLine.message, shown: max(0, shown - PrincessLine.greeting.count - 1))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink2)
        }
    }

    private static func letterTimes(from start: Date) -> [Date] {
        (0...PrincessLine.full.count).map { start.addingTimeInterval(Double($0) * PrincessLine.characterDelay) }
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
