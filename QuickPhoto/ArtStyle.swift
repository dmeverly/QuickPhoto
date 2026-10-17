import SwiftUI

// MARK: - Palette

/// Warm, painterly colors shared by the intro and the main screen.
enum ArtPalette {
    static let ink = Color(red: 0.07, green: 0.06, blue: 0.10)
    static let plum = Color(red: 0.24, green: 0.11, blue: 0.24)
    static let indigo = Color(red: 0.12, green: 0.13, blue: 0.30)
    static let terracotta = Color(red: 0.72, green: 0.34, blue: 0.24)
    /// Solid, deeper terracotta for the backdrop's glow, dark enough to keep text readable.
    static let ember = Color(red: 0.40, green: 0.19, blue: 0.17)
    static let ochre = Color(red: 0.88, green: 0.66, blue: 0.32)
    static let paper = Color(red: 0.97, green: 0.93, blue: 0.86)

    static let brushGradient = LinearGradient(
        colors: [ochre, terracotta, ochre.opacity(0.8)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Typography

extension Font {
    /// Calligraphic script for names and flourishes. Scales with Dynamic Type.
    static func artScript(size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom("SnellRoundhand-Bold", size: size, relativeTo: textStyle)
    }

    /// Elegant serif for titles and labels.
    static func artSerif(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(textStyle, design: .serif, weight: weight)
    }
}

// MARK: - Animated backdrop

/// Slowly drifting mesh of dark, warm colors with a fine paper grain on top,
struct ArtisticBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var isReduceMotionEnabled

    var body: some View {
        TimelineView(.animation(paused: isReduceMotionEnabled)) { timeline in
            let elapsedSeconds = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints(at: elapsedSeconds),
                colors: [
                    ArtPalette.ink, ArtPalette.plum, ArtPalette.ink,
                    ArtPalette.indigo, ArtPalette.ember, ArtPalette.plum,
                    ArtPalette.ink, ArtPalette.indigo, ArtPalette.ink
                ]
            )
        }
        .overlay { PaperGrain().blendMode(.overlay) }
        .ignoresSafeArea()
    }

    /// Edge points stay pinned; the inner points wander gently in slow loops.
    private func meshPoints(at elapsedSeconds: Double) -> [SIMD2<Float>] {
        let slowPhase = Float(elapsedSeconds * 0.25)
        let centerX = 0.5 + 0.18 * sin(slowPhase)
        let centerY = 0.5 + 0.14 * cos(slowPhase * 0.8)
        let topMiddleX = 0.5 + 0.2 * sin(slowPhase * 0.6)
        let bottomMiddleX = 0.5 + 0.2 * cos(slowPhase * 0.7)
        let leftMiddleY = 0.5 + 0.15 * cos(slowPhase * 0.9)
        let rightMiddleY = 0.5 + 0.15 * sin(slowPhase * 0.5)

        return [
            [0, 0], [topMiddleX, 0], [1, 0],
            [0, leftMiddleY], [centerX, centerY], [1, rightMiddleY],
            [0, 1], [bottomMiddleX, 1], [1, 1]
        ]
    }
}

/// Fine speckle texture. Uses a fixed seed so the grain doesn't shimmer between redraws.
private struct PaperGrain: View {
    var body: some View {
        Canvas { context, canvasSize in
            var randomGenerator = SeededRandomGenerator(seed: 1_984)
            let speckleCount = Int(canvasSize.width * canvasSize.height / 150)

            for _ in 0..<speckleCount {
                let speckleOrigin = CGPoint(
                    x: Double.random(in: 0..<canvasSize.width, using: &randomGenerator),
                    y: Double.random(in: 0..<canvasSize.height, using: &randomGenerator)
                )
                let speckleOpacity = Double.random(in: 0.04...0.16, using: &randomGenerator)
                context.fill(
                    Path(CGRect(origin: speckleOrigin, size: CGSize(width: 1, height: 1))),
                    with: .color(.white.opacity(speckleOpacity))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// SplitMix64: a tiny, repeatable random number generator.
private struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

// MARK: - Brush strokes

/// A loose, hand-drawn underline swash. Animate `.trim(from: 0, to:)` to "paint" it in.
struct BrushSwashShape: Shape {
    func path(in rect: CGRect) -> Path {
        var swashPath = Path()
        swashPath.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.15))
        swashPath.addCurve(
            to: CGPoint(x: rect.midX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.18, y: rect.maxY),
            control2: CGPoint(x: rect.width * 0.32, y: rect.minY)
        )
        swashPath.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.2),
            control1: CGPoint(x: rect.width * 0.68, y: rect.maxY),
            control2: CGPoint(x: rect.width * 0.86, y: rect.midY)
        )
        return swashPath
    }
}

/// The brush circle
struct BrushCircleView: View {
    /// 0 = nothing painted yet, 1 = the full stroke.
    let paintedFraction: Double
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            // Main stroke
            Circle()
                .trim(from: 0, to: paintedFraction * 0.93)
                .stroke(
                    AngularGradient(
                        colors: [ArtPalette.ochre, ArtPalette.terracotta, ArtPalette.ochre.opacity(0.5)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Second pass
            Circle()
                .trim(from: 0.04, to: 0.04 + paintedFraction * 0.8)
                .stroke(ArtPalette.paper.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .scaleEffect(1.04)
                .rotationEffect(.degrees(8))
        }
        .rotationEffect(.degrees(-110))
        .accessibilityHidden(true)
    }
}

#Preview("Backdrop") {
    ZStack {
        ArtisticBackdrop()
        BrushCircleView(paintedFraction: 1)
            .frame(width: 240, height: 240)
    }
}
