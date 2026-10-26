import SwiftUI

struct VerifyScreen: View {
    @State private var model = OTPFlowModel()
    @State private var entry = ""
    @State private var sheetVisible = false
    @FocusState private var fieldFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // With the keyboard up on a small phone there isn't room for everything:
            // drop the hint first, then the HUD, but never squeeze the sheet.
            ViewThatFits(in: .vertical) {
                topBar(showsHint: true)
                topBar(showsHint: false)
                Color.clear
            }
            .frame(maxHeight: .infinity, alignment: .top)

            sheet
                .offset(y: sheetVisible ? 0 : 560)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            model.reduceMotion = reduceMotion
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.1)) {
                sheetVisible = true
            }
        }
        .task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
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

    private func topBar(showsHint: Bool) -> some View {
        VStack(spacing: 12) {
            HUDView(score: model.score, coins: model.coins, world: model.world,
                    isMuted: model.isMuted, onToggleMute: { model.toggleMute() })
                .padding(.horizontal, 24)
            if showsHint {
                DemoHint(code: model.demoCode)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.22))
                .frame(width: 38, height: 5)
                .padding(.top, 9)

            HeadlineView(headline: model.headline)
                .padding(.top, 14)
                .padding(.horizontal, 28)

            StageView(model: model, isFocused: fieldFocused)
                .contentShape(Rectangle())
                .onTapGesture {
                    if model.acceptsInput { fieldFocused = true }
                }
                .accessibilityHidden(true)

            FooterView(isVerified: model.phase == .verified,
                       canResend: model.acceptsInput,
                       resendAvailableAt: model.resendAvailableAt,
                       onResend: { model.resend() },
                       onPlayAgain: playAgain)
                .padding(.top, 6)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background { codeField }
        .background(alignment: .top) {
            SheetBackground()
                .ignoresSafeArea(edges: .bottom)
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

    private func playAgain() {
        model.playAgain()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            fieldFocused = true
        }
    }
}

private struct HeadlineView: View {
    let headline: Headline

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                Text(headline.title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                if let subtitle = headline.subtitle {
                    Text(subtitle)
                        .font(.system(size: 14.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            .id(headline)
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 8)),
                                    removal: .opacity.combined(with: .offset(y: -8))))
        }
        // Fixed height so the blocks never jump when the copy changes.
        .frame(height: 78)
        .animation(.easeInOut(duration: 0.35), value: headline)
    }
}

private struct FooterView: View {
    let isVerified: Bool
    let canResend: Bool
    let resendAvailableAt: Date
    let onResend: () -> Void
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            if isVerified {
                Button(action: onPlayAgain) {
                    Label("Play again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .foregroundStyle(.white)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = Int(resendAvailableAt.timeIntervalSince(context.date).rounded(.up))
                    HStack(spacing: 4) {
                        Text("Didn’t receive the code?")
                            .foregroundStyle(.white.opacity(0.45))
                        if remaining > 0 {
                            Text("Resend in 0:\(String(format: "%02d", remaining))")
                                .foregroundStyle(.white.opacity(0.3))
                                .monospacedDigit()
                        } else {
                            Button("Resend", action: onResend)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .disabled(!canResend)
                        }
                    }
                    .font(.system(size: 14))
                }
                .transition(.opacity)
            }
        }
        .frame(height: 34)
        .animation(.easeInOut(duration: 0.3), value: isVerified)
    }
}

private struct SheetBackground: View {
    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 40, topTrailingRadius: 40, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Theme.sheetTop, Theme.sheetBottom], startPoint: .top, endPoint: .bottom))
            .overlay(shape.stroke(.white.opacity(0.06), lineWidth: 1))
    }
}

#Preview {
    VerifyScreen()
}
