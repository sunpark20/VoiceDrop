import AppKit
import os

// MARK: - AppState

final class AppState: NSObject {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.VoiceDrop"
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
    private let hudPanel = HUDPanel()
    private var fileWatcher: FileWatcher?

    // MARK: - Public

    func start() {
        AppState.debug("[DEBUG] AppState.start()")
        setupMenuBar()
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

    private func setupFileWatcher() {
        fileWatcher = FileWatcher(watchPath: configManager.recordingsPath)
        fileWatcher?.delegate = self
        fileWatcher?.startWatching()
    }

    private func validatePaths() {
        let recordingsPath = NSString(string: configManager.recordingsPath).expandingTildeInPath
        let notePath = configManager.noteDirectoryURL.path

        if !FileManager.default.fileExists(atPath: recordingsPath) {
            menuBarManager.updateStatus(.error("녹음 폴더를 찾을 수 없습니다"))
            logger.warning("Recordings path not found: \(recordingsPath)")
        }

        if !FileManager.default.fileExists(atPath: notePath) {
            // 노트 폴더가 없으면 자동 생성 시도
            do {
                try FileManager.default.createDirectory(atPath: notePath, withIntermediateDirectories: true)
            } catch {
                menuBarManager.updateStatus(.error("저장 폴더를 만들 수 없습니다"))
                logger.warning("Note path not found: \(notePath)")
            }
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

    func menuBarManagerDidRequestChangeFolder(_ manager: MenuBarManager) {
        let panel = NSOpenPanel()
        panel.title = "노트 저장 폴더 선택"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = configManager.noteDirectoryURL

        // 메뉴바 앱에서 패널을 앞으로 가져오기
        NSApp.activate(ignoringOtherApps: true)

        if panel.runModal() == .OK, let url = panel.url {
            configManager.saveNoteDirectory(url)
            menuBarManager.rebuildMenu()
            AppState.debug("[DEBUG] Note folder changed to: \(url.path)")
        }
    }

    func menuBarManagerDidRequestQuit(_ manager: MenuBarManager) {
        NSApplication.shared.terminate(nil)
    }
}
