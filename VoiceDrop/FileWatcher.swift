import Foundation
import os

// MARK: - FileWatcherDelegate

protocol FileWatcherDelegate: AnyObject {
    func fileWatcher(_ watcher: FileWatcher, didDetectNewRecording result: RecordingResult, at directoryURL: URL)
    func fileWatcher(_ watcher: FileWatcher, didEncounterError error: FileWatcher.WatchError)
}

// MARK: - FileWatcher

/// Timer 기반 폴링으로 SuperWhisper recordings 디렉토리를 감시한다.
/// DispatchSource(.write)는 macOS 보안 정책/이벤트 병합으로 감지 누락이 발생할 수 있어
/// 2초 간격 폴링이 더 신뢰할 수 있다.
final class FileWatcher {

    enum WatchError {
        case folderNotFound(path: String)
        case parseFailure(path: String)
    }

    weak var delegate: FileWatcherDelegate?
    private(set) var isWatching = false

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.VoiceDrop"
    private let logger = Logger(subsystem: FileWatcher.subsystem, category: "FileWatcher")
    private var pollTimer: Timer?
    private var processedDirectories: Set<String> = []
    private let watchPath: String
    private let pollInterval: TimeInterval = 2.0

    // MARK: - Lifecycle

    init(watchPath: String) {
        self.watchPath = watchPath
    }

    deinit {
        stopWatching()
    }

    // MARK: - Public

    func startWatching() {
        guard !isWatching else { return }

        let expandedPath = NSString(string: watchPath).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            logger.error("Watch directory not found: \(expandedPath)")
            delegate?.fileWatcher(self, didEncounterError: .folderNotFound(path: expandedPath))
            return
        }

        scanExistingDirectories(at: expandedPath)

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollForNewRecordings(at: expandedPath)
        }

        isWatching = true
        AppState.debug("[DEBUG] FileWatcher polling started: \(expandedPath) (\(self.processedDirectories.count) existing skipped)")
    }

    func stopWatching() {
        pollTimer?.invalidate()
        pollTimer = nil
        isWatching = false
    }

    // MARK: - Private

    private func scanExistingDirectories(at path: String) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            logger.warning("Cannot read directory contents: \(path)")
            return
        }
        for item in contents {
            processedDirectories.insert(item)
        }
    }

    private func pollForNewRecordings(at path: String) {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            logger.error("Cannot read directory: \(path)")
            delegate?.fileWatcher(self, didEncounterError: .folderNotFound(path: path))
            return
        }

        for item in contents where !processedDirectories.contains(item) {
            let directoryURL = URL(fileURLWithPath: path).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                processedDirectories.insert(item)
                continue
            }

            let metaURL = directoryURL.appendingPathComponent("meta.json")
            guard FileManager.default.fileExists(atPath: metaURL.path) else {
                // meta.json 아직 없음 — SuperWhisper가 아직 처리 중. 다음 폴링에서 재시도.
                continue
            }

            // meta.json 발견 — 처리 완료로 마킹하고 파싱
            processedDirectories.insert(item)
            AppState.debug("[DEBUG] New recording detected: \(item)")

            if let result = MetaJSONParser.parse(fileURL: metaURL) {
                delegate?.fileWatcher(self, didDetectNewRecording: result, at: directoryURL)
            } else {
                logger.error("Parse failed: \(metaURL.path)")
                delegate?.fileWatcher(self, didEncounterError: .parseFailure(path: metaURL.path))
            }
        }
    }
}
