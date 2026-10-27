import SwiftUI

/// What Mario says after a miss, in a bubble with stepped pixel corners.
struct SpeechBubble: View {
    let wrongSlots: [Int]
    let tailOnRight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.headline(for: wrongSlots.count))
                .font(.system(size: 16, weight: .heavy).width(.expanded))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if wrongSlots.count == StageLayout.slotCount {
                Text("Retype all four")
                    .foregroundStyle(Theme.ink2)
            } else {
                HStack(spacing: 5) {
                    Text("Fix")
                        .foregroundStyle(Theme.ink2)
                    ForEach(Array(wrongSlots.enumerated()), id: \.offset) { index, slot in
                        if index > 0 {
                            Text(index == wrongSlots.count - 1 ? "and" : ",")
                                .foregroundStyle(Theme.ink2)
                        }
                        SlotChip(number: slot + 1)
                    }
                }
            }
        }
        .font(.system(size: 13.5, weight: .medium))
        .padding(.horizontal, 17)
        .frame(width: StageLayout.bubbleSize.width, height: StageLayout.bubbleSize.height, alignment: .leading)
        .background(PixelFrame())
        .overlay(alignment: tailOnRight ? .bottomTrailing : .bottomLeading) {
            PixelSprite(image: SpriteImage.bubbleTail, size: CGSize(width: 15, height: 15))
                .scaleEffect(x: tailOnRight ? 1 : -1, y: 1)
                .offset(x: tailOnRight ? -22 : 22, y: 12)
        }
        .compositingGroup()
        .softShadow(contact: 0.04, ambient: 0.06, radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }

    static func headline(for count: Int) -> String {
        switch count {
        case 1: return "One is off!"
        case 2: return "Two are off!"
        case 3: return "Three are off!"
        default: return "All four are off!"
        }
    }
}

private struct SlotChip: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(Theme.redSkirt)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.redFace))
    }
}

/// Ink outline and white fill, both with stepped corners.
struct PixelFrame: View {
    var body: some View {
        ZStack {
            SteppedRectangle(step: 3, steps: 2).fill(Theme.ink)
            SteppedRectangle(step: 3, steps: 1).fill(.white).padding(3)
        }
    }
}

/// A rectangle whose corners are cut into `steps` stair steps of `step` points each.
struct SteppedRectangle: Shape {
    var step: CGFloat
    var steps: Int

    func path(in rect: CGRect) -> Path {
        let s = step
        let n = CGFloat(steps)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + n * s, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - n * s, y: rect.minY))
        for i in 1...steps {
            let k = CGFloat(i)
            path.addLine(to: CGPoint(x: rect.maxX - (n - k) * s, y: rect.minY + (k - 1) * s))
            path.addLine(to: CGPoint(x: rect.maxX - (n - k) * s, y: rect.minY + k * s))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - n * s))
        for i in 1...steps {
            let k = CGFloat(i)
            path.addLine(to: CGPoint(x: rect.maxX - (k - 1) * s, y: rect.maxY - (n - k) * s))
            path.addLine(to: CGPoint(x: rect.maxX - k * s, y: rect.maxY - (n - k) * s))
        }
        path.addLine(to: CGPoint(x: rect.minX + n * s, y: rect.maxY))
        for i in 1...steps {
            let k = CGFloat(i)
            path.addLine(to: CGPoint(x: rect.minX + (n - k) * s, y: rect.maxY - (k - 1) * s))
            path.addLine(to: CGPoint(x: rect.minX + (n - k) * s, y: rect.maxY - k * s))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + n * s))
        for i in 1...steps {
            let k = CGFloat(i)
            path.addLine(to: CGPoint(x: rect.minX + (k - 1) * s, y: rect.minY + (n - k) * s))
            path.addLine(to: CGPoint(x: rect.minX + k * s, y: rect.minY + (n - k) * s))
        }
        path.closeSubpath()
        return path
    }
}
