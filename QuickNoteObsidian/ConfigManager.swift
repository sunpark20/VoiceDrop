import Foundation
import os

// MARK: - Config Keys

enum ConfigKey {
    static let recordingsPath = "recordingsPath"
    static let vaultPath = "vaultPath"
    static let noteFolderSubpath = "noteFolderSubpath"
}

// MARK: - ConfigManager

final class ConfigManager {

    static let shared = ConfigManager()

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.QuickNoteObsidian"
    private let logger = Logger(subsystem: ConfigManager.subsystem, category: "ConfigManager")
    private let defaults = UserDefaults.standard

    private let defaultRecordingsPath = NSString("~/Documents/superwhisper/recordings").expandingTildeInPath
    private let defaultVaultPath = NSString("~/Documents/Obsidian Vault").expandingTildeInPath

    // MARK: - Properties

    var recordingsPath: String {
        get { defaults.string(forKey: ConfigKey.recordingsPath) ?? defaultRecordingsPath }
        set { defaults.set(newValue, forKey: ConfigKey.recordingsPath) }
    }

    var vaultPath: String {
        get { defaults.string(forKey: ConfigKey.vaultPath) ?? defaultVaultPath }
        set { defaults.set(newValue, forKey: ConfigKey.vaultPath) }
    }

    var noteFolderSubpath: String {
        get { defaults.string(forKey: ConfigKey.noteFolderSubpath) ?? "Project/아이디어" }
        set { defaults.set(newValue, forKey: ConfigKey.noteFolderSubpath) }
    }

    var noteDirectoryURL: URL {
        URL(fileURLWithPath: vaultPath).appendingPathComponent(noteFolderSubpath)
    }

    // MARK: - Lifecycle

    private init() {
        defaults.register(defaults: [
            ConfigKey.recordingsPath: defaultRecordingsPath,
            ConfigKey.vaultPath: defaultVaultPath,
            ConfigKey.noteFolderSubpath: "Project/아이디어"
        ])
        logger.info("Config loaded — recordings: \(self.recordingsPath), vault: \(self.vaultPath)")
    }
}
