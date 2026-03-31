import Foundation
import os

// MARK: - Config Keys

enum ConfigKey {
    static let recordingsPath = "recordingsPath"
    static let noteDirectoryPath = "noteDirectoryPath"
}

// MARK: - ConfigManager

final class ConfigManager {

    static let shared = ConfigManager()

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.VoiceDrop"
    private let logger = Logger(subsystem: ConfigManager.subsystem, category: "ConfigManager")
    private let defaults = UserDefaults.standard

    private let defaultRecordingsPath = NSString("~/Documents/superwhisper/recordings").expandingTildeInPath
    private let defaultNoteDirectoryPath = NSString("~/Downloads").expandingTildeInPath

    // MARK: - Properties

    var recordingsPath: String {
        get { defaults.string(forKey: ConfigKey.recordingsPath) ?? defaultRecordingsPath }
        set { defaults.set(newValue, forKey: ConfigKey.recordingsPath) }
    }

    var noteDirectoryURL: URL {
        let path = defaults.string(forKey: ConfigKey.noteDirectoryPath) ?? defaultNoteDirectoryPath
        return URL(fileURLWithPath: path)
    }

    // MARK: - Public

    func saveNoteDirectory(_ url: URL) {
        defaults.set(url.path, forKey: ConfigKey.noteDirectoryPath)
        logger.info("Note directory changed: \(url.path)")
    }

    // MARK: - Lifecycle

    private init() {
        defaults.register(defaults: [
            ConfigKey.recordingsPath: defaultRecordingsPath,
            ConfigKey.noteDirectoryPath: defaultNoteDirectoryPath
        ])
        logger.info("Config loaded — notes: \(self.noteDirectoryURL.path)")
    }
}
