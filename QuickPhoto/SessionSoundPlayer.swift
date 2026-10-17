import AudioToolbox

final class SessionSoundPlayer {
    var isSoundEnabled = true

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
