import SwiftUI

/// Launch intro: a brush circle paints itself in, then "Made for Lorelei"
/// is written across the middle with a flourish underneath, followed by
/// "with Love". Tap to skip.
struct IntroView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var isReduceMotionEnabled

    @State private var brushCircleFraction: Double = 0
    @State private var isMadeForVisible = false
    @State private var nameRevealFraction: Double = 0
    @State private var swashFraction: Double = 0
    @State private var isWithLoveVisible = false
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            ArtisticBackdrop()

            BrushCircleView(paintedFraction: brushCircleFraction, lineWidth: 12)
                .frame(width: 300, height: 300)
                .opacity(0.9)

            VStack(spacing: 4) {
                Text("Made for")
                    .font(.artSerif(.title3).italic())
                    .tracking(4)
                    .foregroundStyle(ArtPalette.paper.opacity(0.8))
                    .opacity(isMadeForVisible ? 1 : 0)
                    .offset(y: isMadeForVisible ? 0 : 12)

                Text("Lorelei")
                    .font(.artScript(size: 72))
                    .foregroundStyle(ArtPalette.paper)
                    .shadow(color: ArtPalette.terracotta.opacity(0.6), radius: 12)
                    .padding(.horizontal, 16)    // room for the script's overhanging flourishes
                    // Sweep a mask left to right so the name looks hand-written.
                    .mask {
                        Rectangle().scaleEffect(x: nameRevealFraction, anchor: .leading)
                    }

                BrushSwashShape()
                    .trim(from: 0, to: swashFraction)
                    .stroke(ArtPalette.brushGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 190, height: 18)

                Text("with Love")
                    .font(.artScript(size: 34, relativeTo: .title))
                    .foregroundStyle(ArtPalette.ochre)
                    .padding(.top, 6)
                    .opacity(isWithLoveVisible ? 1 : 0)
                    .blur(radius: isWithLoveVisible ? 0 : 6)
                    .offset(y: isWithLoveVisible ? 0 : 10)
            }
        }
        .contentShape(.rect)
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Made for Lorelei, with Love")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to skip")
        .task { await playIntro() }
    }

    private func playIntro() async {
        if isReduceMotionEnabled {
            brushCircleFraction = 1
            isMadeForVisible = true
            nameRevealFraction = 1
            swashFraction = 1
            isWithLoveVisible = true
            try? await Task.sleep(for: .seconds(2))
            finish()
            return
        }

        withAnimation(.easeInOut(duration: 1.4)) { brushCircleFraction = 1 }
        withAnimation(.easeOut(duration: 0.7).delay(0.5)) { isMadeForVisible = true }
        withAnimation(.easeInOut(duration: 1.1).delay(0.9)) { nameRevealFraction = 1 }
        withAnimation(.easeOut(duration: 0.6).delay(1.9)) { swashFraction = 1 }
        // A beat after the name is finished, the dedication drifts in on its own.
        withAnimation(.easeOut(duration: 0.9).delay(2.7)) { isWithLoveVisible = true }

        // Hold the finished composition for a moment before moving on.
        try? await Task.sleep(for: .seconds(4.4))
        finish()
    }

    /// Guarded so a tap and the timer can't both end the intro.
    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinished()
    }
}

#Preview {
    IntroView {}
}
