import SwiftUI
import PhotosUI

enum SessionState {
    case idle, running, paused
}

@MainActor
@Observable
final class SketchSessionViewModel {
    // MARK: - State the view reads

    private(set) var currentPhoto: UIImage?
    private(set) var savedPhotoCount = 0
    private(set) var isImporting = false

    private(set) var sessionState: SessionState = .idle
    private(set) var secondsPerPhoto: Double
    private(set) var currentPoseIndex = 0
    private(set) var remainingSecondsInPose: Double = 0

    var isGrayscaleEnabled: Bool {
        didSet { settingsStore.isGrayscaleEnabled = isGrayscaleEnabled }
    }

    var isSoundEnabled: Bool {
        didSet {
            settingsStore.isSoundEnabled = isSoundEnabled
            soundPlayer.isSoundEnabled = isSoundEnabled
        }
    }

    /// Common figure-drawing pose lengths: 30 sec, 1, 2, 5 and 10 min.
    let standardSecondsPerPhotoOptions: [Double] = [30, 60, 120, 300, 600]

    // MARK: - Derived values for the view

    var isSessionActive: Bool { sessionState == .running || sessionState == .paused }

    var isUsingCustomSecondsPerPhoto: Bool { !standardSecondsPerPhotoOptions.contains(secondsPerPhoto) }

    var currentPoseDurationInSeconds: Double { secondsPerPhoto }

    /// 1.0 when a pose begins, counting down to 0.0 when it ends.
    var poseTimeRemainingFraction: Double {
        guard currentPoseDurationInSeconds > 0 else { return 0 }
        return remainingSecondsInPose / currentPoseDurationInSeconds
    }

    var isPoseEndingSoon: Bool {
        isSessionActive && remainingSecondsInPose <= warningLeadTimeInSeconds
    }

    var poseProgressDescription: String { "Photo \(currentPoseIndex + 1)" }

    // MARK: - Dependencies and internals

    private let photoStorage: PhotoStorage
    private let soundPlayer: SessionSoundPlayer
    private let settingsStore: SessionSettingsStore
    private var photoShuffleBag: ShuffleBag<URL>

    private var sessionClockTask: Task<Void, Never>?
    private var hasPlayedWarningForCurrentPose = false

    private let warningLeadTimeInSeconds: Double = 5
    private let clockTickInterval: Duration = .milliseconds(100)

    init(
        photoStorage: PhotoStorage = PhotoStorage(),
        soundPlayer: SessionSoundPlayer = SessionSoundPlayer(),
        settingsStore: SessionSettingsStore = SessionSettingsStore()
    ) {
        self.photoStorage = photoStorage
        self.soundPlayer = soundPlayer
        self.settingsStore = settingsStore

        secondsPerPhoto = settingsStore.secondsPerPhoto
        isGrayscaleEnabled = settingsStore.isGrayscaleEnabled
        isSoundEnabled = settingsStore.isSoundEnabled
        soundPlayer.isSoundEnabled = settingsStore.isSoundEnabled

        let savedPhotoURLs = photoStorage.allSavedPhotoURLs()
        photoShuffleBag = ShuffleBag(elements: savedPhotoURLs)
        savedPhotoCount = savedPhotoURLs.count
    }

    // MARK: - Photo set management

    func importPhotos(from selectedPickerItems: [PhotosPickerItem]) async {
        guard !selectedPickerItems.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }

        for pickerItem in selectedPickerItems {
            guard let originalImageData = try? await pickerItem.loadTransferable(type: Data.self) else {
                continue
            }
            try? photoStorage.savePhoto(from: originalImageData)
        }

        reloadPhotoSet()
    }

    func removeAllPhotos() {
        endSession()
        try? photoStorage.deleteAllPhotos()
        reloadPhotoSet()
    }

    // MARK: - Session control

    func selectSecondsPerPhoto(_ newSecondsPerPhoto: Double) {
        guard !isSessionActive, newSecondsPerPhoto > 0 else { return }
        secondsPerPhoto = newSecondsPerPhoto
        settingsStore.secondsPerPhoto = newSecondsPerPhoto
    }

    func togglePlayPause() {
        switch sessionState {
        case .idle:    startSession()
        case .running: pauseSession()
        case .paused:  resumeSession()
        }
    }

    func startSession() {
        guard !photoShuffleBag.isEmpty else { return }
        beginPose(at: 0)
        sessionState = .running
        soundPlayer.playNewPoseStartedCue()
        keepScreenAwake(true)
        startSessionClock()
    }

    func pauseSession() {
        guard sessionState == .running else { return }
        sessionState = .paused
        stopSessionClock()
        keepScreenAwake(false)
    }

    func resumeSession() {
        guard sessionState == .paused else { return }
        sessionState = .running
        keepScreenAwake(true)
        startSessionClock()
    }

    func endSession() {
        stopSessionClock()
        sessionState = .idle
        currentPhoto = nil
        keepScreenAwake(false)
    }


    func swapCurrentPhoto() {
        guard isSessionActive else { return }
        beginPose(at: currentPoseIndex)
    }

    // MARK: - Session clock

    private func startSessionClock() {
        stopSessionClock()

        sessionClockTask = Task { [weak self, clockTickInterval] in
            let clock = ContinuousClock()
            var previousTickInstant = clock.now

            while !Task.isCancelled {
                try? await Task.sleep(for: clockTickInterval)

                let currentTickInstant = clock.now
                let elapsedSinceLastTick = previousTickInstant.duration(to: currentTickInstant)
                previousTickInstant = currentTickInstant

                guard let self else { return }
                self.advanceSessionClock(byElapsedSeconds: elapsedSinceLastTick.totalSeconds)
            }
        }
    }

    private func stopSessionClock() {
        sessionClockTask?.cancel()
        sessionClockTask = nil
    }

    private func advanceSessionClock(byElapsedSeconds elapsedSeconds: Double) {
        guard sessionState == .running else { return }

        remainingSecondsInPose = max(0, remainingSecondsInPose - elapsedSeconds)

        if shouldPlayPoseEndingWarning {
            soundPlayer.playPoseEndingSoonCue()
            hasPlayedWarningForCurrentPose = true
        }

        if remainingSecondsInPose <= 0 {
            completeCurrentPose()
        }
    }

    /// Very short poses skip the warning so the cues don't overlap.
    private var shouldPlayPoseEndingWarning: Bool {
        let poseIsLongEnoughForWarning = currentPoseDurationInSeconds > warningLeadTimeInSeconds * 2
        return poseIsLongEnoughForWarning
            && !hasPlayedWarningForCurrentPose
            && remainingSecondsInPose <= warningLeadTimeInSeconds
    }

    private func completeCurrentPose() {
        beginPose(at: currentPoseIndex + 1)
        soundPlayer.playNewPoseStartedCue()
    }

    // MARK: - Private helpers

    private func beginPose(at poseIndex: Int) {
        currentPoseIndex = poseIndex
        remainingSecondsInPose = secondsPerPhoto
        hasPlayedWarningForCurrentPose = false
        showNextPhoto()
    }

    private func showNextPhoto() {
        guard let nextPhotoURL = photoShuffleBag.drawNext() else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            currentPhoto = photoStorage.loadImage(at: nextPhotoURL)
        }
    }

    private func reloadPhotoSet() {
        let savedPhotoURLs = photoStorage.allSavedPhotoURLs()
        photoShuffleBag = ShuffleBag(elements: savedPhotoURLs)
        savedPhotoCount = savedPhotoURLs.count
    }

    private func keepScreenAwake(_ shouldStayAwake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = shouldStayAwake
    }
}
