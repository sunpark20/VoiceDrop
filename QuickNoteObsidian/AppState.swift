import AppKit
import os

// MARK: - AppState

final class AppState: NSObject {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.QuickNoteObsidian"
    private let logger = Logger(subsystem: AppState.subsystem, category: "AppState")

    static func debug(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        let logPath = "/tmp/qno_debug.log"
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: line.data(using: .utf8))
        }
    }

    private let configManager = ConfigManager.shared
    private let menuBarManager = MenuBarManager()
    private let hotkeyManager = HotkeyManager()
    private let hudPanel = HUDPanel()
    private var fileWatcher: FileWatcher?

    // MARK: - Public

    func start() {
        AppState.debug("[DEBUG] AppState.start()")
        setupMenuBar()
        setupHotkey()
        setupFileWatcher()
        validatePaths()
        AppState.debug("[DEBUG] AppState started — watching: \(configManager.recordingsPath)")
        AppState.debug("[DEBUG] Notes will go to: \(configManager.noteDirectoryURL.path)")
    }

    // MARK: - Private Setup

    private func setupMenuBar() {
        menuBarManager.delegate = self
        menuBarManager.setup()
    }

    private func setupHotkey() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.triggerRecording()
        }
        hotkeyManager.register()
    }

    private func setupFileWatcher() {
        fileWatcher = FileWatcher(watchPath: configManager.recordingsPath)
        fileWatcher?.delegate = self
        fileWatcher?.startWatching()
    }

    private func validatePaths() {
        let recordingsPath = NSString(string: configManager.recordingsPath).expandingTildeInPath
        let vaultPath = configManager.vaultPath

        if !FileManager.default.fileExists(atPath: recordingsPath) {
            menuBarManager.updateStatus(.error("녹음 폴더를 찾을 수 없습니다"))
            logger.warning("Recordings path not found: \(recordingsPath)")
        }

        if !FileManager.default.fileExists(atPath: vaultPath) {
            menuBarManager.updateStatus(.error("Obsidian Vault를 찾을 수 없습니다"))
            logger.warning("Vault path not found: \(vaultPath)")
        }
    }

    // MARK: - Actions

    private func triggerRecording() {
        guard let url = URL(string: "superwhisper://record") else { return }

        if !NSWorkspace.shared.open(url) {
            logger.error("Failed to open SuperWhisper deep link")
            menuBarManager.updateStatus(.error("SuperWhisper를 실행할 수 없습니다"))
        }
    }
}

// MARK: - FileWatcherDelegate

extension AppState: FileWatcherDelegate {

    func fileWatcher(_ watcher: FileWatcher, didDetectNewRecording result: RecordingResult, at directoryURL: URL) {
        AppState.debug("[DEBUG] didDetectNewRecording: \(result.text.prefix(50))")
        let noteDirectory = configManager.noteDirectoryURL
        AppState.debug("[DEBUG] Creating note in: \(noteDirectory.path)")

        guard let note = NoteCreator.createNote(from: result, in: noteDirectory) else {
            AppState.debug("[DEBUG] ❌ NoteCreator.createNote failed")
            menuBarManager.updateStatus(.error("노트 생성에 실패했습니다"))
            return
        }

        AppState.debug("[DEBUG] ✅ Note created: \(note.title) at \(note.fileURL.path)")
        hudPanel.show(text: result.text, title: note.title)
        menuBarManager.addRecentRecord(title: note.title, fileURL: note.fileURL)
        menuBarManager.updateStatus(.normal)
    }

    func fileWatcher(_ watcher: FileWatcher, didEncounterError error: FileWatcher.WatchError) {
        switch error {
        case .folderNotFound(let path):
            menuBarManager.updateStatus(.error("녹음 폴더를 찾을 수 없습니다"))
            logger.error("Watch folder not found: \(path)")
        case .parseFailure(let path):
            menuBarManager.updateStatus(.error("텍스트를 읽을 수 없습니다"))
            logger.error("Parse failure: \(path)")
        }
    }
}

// MARK: - MenuBarManagerDelegate

extension AppState: MenuBarManagerDelegate {

    func menuBarManagerDidRequestRecording(_ manager: MenuBarManager) {
        triggerRecording()
    }

    func menuBarManagerDidRequestQuit(_ manager: MenuBarManager) {
        NSApplication.shared.terminate(nil)
    }
}
