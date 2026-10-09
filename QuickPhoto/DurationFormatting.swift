import Foundation

enum DurationFormatting {
    /// Countdown style: 0:30, 2:00, 10:00
    static func clockStyle(of durationInSeconds: Double) -> String {
        let wholeSecondsRemaining = Int(durationInSeconds.rounded(.up))
        let minutes = wholeSecondsRemaining / 60
        let seconds = wholeSecondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Readable style: 30 sec, 2 min, 1 min 30 sec
    static func shortDescription(of durationInSeconds: Double) -> String {
        let wholeSeconds = Int(durationInSeconds)
        let minutes = wholeSeconds / 60
        let leftoverSeconds = wholeSeconds % 60

        switch (minutes, leftoverSeconds) {
        case (0, _): return "\(leftoverSeconds) sec"
        case (_, 0): return "\(minutes) min"
        default:     return "\(minutes) min \(leftoverSeconds) sec"
        }
    }
}

extension Duration {
    var totalSeconds: Double {
        let (wholeSeconds, attoseconds) = components
        return Double(wholeSeconds) + Double(attoseconds) / 1e18
    }
}
