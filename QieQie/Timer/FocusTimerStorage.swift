import Foundation

enum FocusTimerStorage {
    private enum Key {
        static let focusDuration = "focusTimer.configuration.focusDuration"
        static let shortBreakDuration = "focusTimer.configuration.shortBreakDuration"
        static let longBreakDuration = "focusTimer.configuration.longBreakDuration"
        static let longBreakInterval = "focusTimer.configuration.longBreakInterval"
        static let autoStartBreak = "focusTimer.configuration.autoStartBreak"
        static let autoStartNextFocus = "focusTimer.configuration.autoStartNextFocus"
        static let autoAdvance = "focusTimer.configuration.autoAdvance"
        static let currentTaskName = "focusTimer.currentTaskName"
        static let selectedTagName = "focusTimer.selectedTagName"
        static let legacyAvailableTags = "focusTimer.availableTags"
    }

    static func persist(
        configuration: FocusTimerConfiguration,
        in userDefaults: UserDefaults
    ) {
        userDefaults.set(configuration.focusDuration, forKey: Key.focusDuration)
        userDefaults.set(configuration.shortBreakDuration, forKey: Key.shortBreakDuration)
        userDefaults.set(configuration.longBreakDuration, forKey: Key.longBreakDuration)
        userDefaults.set(configuration.longBreakInterval, forKey: Key.longBreakInterval)
        userDefaults.set(configuration.autoStartBreak, forKey: Key.autoStartBreak)
        userDefaults.set(configuration.autoStartNextFocus, forKey: Key.autoStartNextFocus)
        userDefaults.removeObject(forKey: Key.autoAdvance)
    }

    static func persist(currentTaskName: String, in userDefaults: UserDefaults) {
        userDefaults.set(currentTaskName, forKey: Key.currentTaskName)
    }

    static func persist(selectedTagName: String?, in userDefaults: UserDefaults) {
        if let selectedTagName {
            userDefaults.set(selectedTagName, forKey: Key.selectedTagName)
        } else {
            userDefaults.removeObject(forKey: Key.selectedTagName)
        }
    }

    static func persistLegacyAvailableTags(_ availableTags: [String], in userDefaults: UserDefaults) {
        userDefaults.set(availableTags, forKey: Key.legacyAvailableTags)
    }

    static func loadConfiguration(from userDefaults: UserDefaults) -> FocusTimerConfiguration {
        let defaults = FocusTimerConfiguration.default
        let focusDuration = userDefaults.object(forKey: Key.focusDuration) as? Double ?? defaults.focusDuration
        let shortBreakDuration = userDefaults.object(forKey: Key.shortBreakDuration) as? Double ?? defaults.shortBreakDuration
        let longBreakDuration = userDefaults.object(forKey: Key.longBreakDuration) as? Double ?? defaults.longBreakDuration
        let longBreakInterval = userDefaults.object(forKey: Key.longBreakInterval) as? Int ?? defaults.longBreakInterval
        let legacyAutoAdvance = userDefaults.object(forKey: Key.autoAdvance) as? Bool
        let autoStartBreak = userDefaults.object(forKey: Key.autoStartBreak) as? Bool
            ?? legacyAutoAdvance
            ?? defaults.autoStartBreak
        let autoStartNextFocus = userDefaults.object(forKey: Key.autoStartNextFocus) as? Bool
            ?? legacyAutoAdvance
            ?? defaults.autoStartNextFocus

        return FocusTimerConfiguration(
            focusDuration: focusDuration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            longBreakInterval: longBreakInterval,
            autoStartBreak: autoStartBreak,
            autoStartNextFocus: autoStartNextFocus
        ).normalized()
    }

    static func loadCurrentTaskName(from userDefaults: UserDefaults) -> String {
        normalizeTaskNameInput(userDefaults.string(forKey: Key.currentTaskName) ?? "")
    }

    static func loadSelectedTagName(from userDefaults: UserDefaults) -> String? {
        FocusTagCatalog.normalizeTagName(userDefaults.string(forKey: Key.selectedTagName))
    }

    static func loadLegacyAvailableTags(from userDefaults: UserDefaults) -> [String] {
        let storedTags = userDefaults.stringArray(forKey: Key.legacyAvailableTags) ?? FocusTagCatalog.defaultTags
        return FocusTagCatalog.normalizedTags(from: storedTags)
    }

    static func clearLegacyAvailableTags(in userDefaults: UserDefaults) {
        userDefaults.removeObject(forKey: Key.legacyAvailableTags)
    }

    static func normalizeTaskNameInput(_ taskName: String) -> String {
        FocusTagCatalog.sanitize(taskName, maxLength: 80)
    }
}
