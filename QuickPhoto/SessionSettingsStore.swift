import Foundation

/// Remembers her settings between launches.
final class SessionSettingsStore {
    private let userDefaults: UserDefaults

    private enum StorageKey {
        static let secondsPerPhoto = "secondsPerPhoto"
        static let isGrayscaleEnabled = "isGrayscaleEnabled"
        static let isSoundEnabled = "isSoundEnabled"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Defaults to one minute the first time the app runs.
    var secondsPerPhoto: Double {
        get { userDefaults.object(forKey: StorageKey.secondsPerPhoto) as? Double ?? 60 }
        set { userDefaults.set(newValue, forKey: StorageKey.secondsPerPhoto) }
    }

    var isGrayscaleEnabled: Bool {
        get { userDefaults.bool(forKey: StorageKey.isGrayscaleEnabled) }
        set { userDefaults.set(newValue, forKey: StorageKey.isGrayscaleEnabled) }
    }

    /// Defaults to on the first time the app runs.
    var isSoundEnabled: Bool {
        get { userDefaults.object(forKey: StorageKey.isSoundEnabled) as? Bool ?? true }
        set { userDefaults.set(newValue, forKey: StorageKey.isSoundEnabled) }
    }
}
