import AudioToolbox

/// Plays short cues so the artist can keep her eyes on the paper.
/// Uses built-in iOS system sounds, so no audio files need to be added to the project.
/// Note: system sounds are muted when the phone's silent switch is on.
final class SessionSoundPlayer {
    var isSoundEnabled = true

    /// The numeric IDs are iOS system sounds; swap them for others if she prefers different tones.
    private enum SessionCue: SystemSoundID {
        case poseEndingSoon = 1057   // soft "tink"
        case newPoseStarted = 1016   // short "swoosh"
        case sessionFinished = 1025  // fanfare
    }

    func playPoseEndingSoonCue() { play(.poseEndingSoon) }
    func playNewPoseStartedCue() { play(.newPoseStarted) }
    func playSessionFinishedCue() { play(.sessionFinished) }

    private func play(_ sessionCue: SessionCue) {
        guard isSoundEnabled else { return }
        AudioServicesPlaySystemSound(sessionCue.rawValue)
    }
}
