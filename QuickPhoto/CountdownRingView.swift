import SwiftUI

/// Circular countdown that drains as the pose time runs out and turns orange near the end.
struct CountdownRingView: View {
    let timeRemainingFraction: Double
    let remainingSeconds: Double
    let isEndingSoon: Bool

    private let ringLineWidth: CGFloat = 6
    private let ringDiameter: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: ringLineWidth)

            Circle()
                .trim(from: 0, to: timeRemainingFraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: timeRemainingFraction)

            Text(DurationFormatting.clockStyle(of: remainingSeconds))
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .padding(10)
        .background(.black.opacity(0.45), in: Circle())
    }

    private var ringColor: Color {
        isEndingSoon ? .orange : .white
    }
}

#Preview {
    ZStack {
        Color.gray
        CountdownRingView(timeRemainingFraction: 0.65, remainingSeconds: 39, isEndingSoon: false)
    }
}
