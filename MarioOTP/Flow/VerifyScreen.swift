import SwiftUI

struct VerifyScreen: View {
    @State private var model = OTPFlowModel()
    @State private var entry = ""
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isVerified: Bool { model.headline == .verified }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(isMuted: model.isMuted,
                   onClose: { startOver() },
                   onToggleMute: { model.toggleMute() })
                .padding(.horizontal, 20)
                .padding(.top, 6)

            VStack(spacing: 0) {
                HeadlineView(headline: model.headline)
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                StageView(model: model, isFocused: fieldFocused)
                    .padding(.top, 10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if model.acceptsInput { fieldFocused = true }
                    }
                    .accessibilityHidden(true)

                ZStack {
                    if isVerified {
                        PrincessDialog(startedAt: model.dialogStartedAt)
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                    } else {
                        FooterView(isChecking: model.phase == .checking,
                                   canResend: model.acceptsInput,
                                   resendAvailableAt: model.resendAvailableAt,
                                   demoCode: model.demoCode,
                                   onResend: { model.resend() })
                            .transition(.opacity)
                    }
                }
                .padding(.top, isVerified ? 16 : 6)
                .animation(.easeOut(duration: 0.25), value: isVerified)
            }
            // Typing happens up top, clear of the keyboard; the ending settles into the middle.
            .frame(maxHeight: .infinity, alignment: isVerified ? .center : .top)
        }
        .background { codeField }
        .background { PaperBackground().ignoresSafeArea() }
        .preferredColorScheme(.light)
        .onAppear { model.reduceMotion = reduceMotion }
        .task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            fieldFocused = true
        }
        .onChange(of: reduceMotion) { _, newValue in
            model.reduceMotion = newValue
        }
        .onChange(of: model.headline) { _, headline in
            // Get the keyboard out of the way for the finale.
            if headline == .verified { fieldFocused = false }
        }
    }

    /// The real input: an invisible one-time-code field, so SMS autofill and paste just work.
    private var codeField: some View {
        TextField("", text: $entry)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($fieldFocused)
            .frame(width: 1, height: 1)
            .opacity(0.02)
            .accessibilityLabel("Verification code")
            .accessibilityValue("\(model.entryText.count) of \(model.editableSlots.count) digits entered")
            .onChange(of: entry) { _, newValue in
                model.updateEntry(newValue)
                if entry != model.entryText { entry = model.entryText }
            }
            .onChange(of: model.entryText) { _, text in
                if entry != text { entry = text }
            }
    }

    private func startOver() {
        model.startOver()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            fieldFocused = true
        }
    }
}

private struct HeadlineView: View {
    let headline: Headline

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                Text(headline.title)
                    .font(.system(size: 23, weight: .heavy).width(.expanded))
                    .kerning(-0.3)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(headline.subtitle)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .id(headline)
            .transition(.blurReplace)
        }
        // Fixed height so the keys never jump when the copy changes.
        .frame(height: 84, alignment: .top)
        .animation(.easeInOut(duration: 0.35), value: headline)
    }
}

private struct FooterView: View {
    let isChecking: Bool
    let canResend: Bool
    let resendAvailableAt: Date
    let demoCode: String
    let onResend: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if isChecking {
                CheckingLabel()
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = Int(resendAvailableAt.timeIntervalSince(context.date).rounded(.up))
                    HStack(spacing: 6) {
                        Text("Didn’t get it?")
                            .foregroundStyle(Theme.ink2)
                        if remaining > 0 {
                            Text("Resend in")
                                .foregroundStyle(Theme.ink2)
                            MonoChip(text: String(format: "0:%02d", remaining))
                        } else {
                            Button("Resend", action: onResend)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .underline()
                                .disabled(!canResend)
                        }
                    }
                    .font(.system(size: 14.5, weight: .medium))
                }
            }
            HStack(spacing: 6) {
                Text("Demo code")
                    .foregroundStyle(Theme.ink3)
                MonoChip(text: demoCode, ink: Theme.goldInk)
                    .contentTransition(.numericText())
            }
            .font(.system(size: 13, weight: .medium))
            .animation(.snappy, value: demoCode)
            .accessibilityElement(children: .combine)
        }
        .frame(height: 58, alignment: .top)
    }
}

private struct CheckingLabel: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let dots = abs(Int(context.date.timeIntervalSinceReferenceDate / 0.35)) % 3 + 1
            HStack(spacing: 4) {
                Text("Checking")
                    .foregroundStyle(Theme.ink2)
                Text(String(repeating: "·", count: dots) + String(repeating: " ", count: 3 - dots))
                    .font(.system(size: 14.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Theme.ink3)
            }
            .font(.system(size: 14.5, weight: .medium))
        }
    }
}

private struct MonoChip: View {
    let text: String
    var ink: Color = Theme.ink3

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .foregroundStyle(ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.line))
    }
}

/// Warm paper with a faint dot grid.
private struct PaperBackground: View {
    var body: some View {
        Theme.paper
            .overlay {
                Canvas { context, size in
                    let spacing: CGFloat = 18
                    var dots = Path()
                    var y: CGFloat = 4
                    while y < size.height {
                        var x: CGFloat = 4
                        while x < size.width {
                            dots.addEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                            x += spacing
                        }
                        y += spacing
                    }
                    context.fill(dots, with: .color(Theme.paperDot))
                }
            }
    }
}

#Preview {
    VerifyScreen()
}
