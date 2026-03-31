import AppKit
import os

// MARK: - MenuBarManagerDelegate

protocol MenuBarManagerDelegate: AnyObject {
    func menuBarManagerDidRequestRecording(_ manager: MenuBarManager)
    func menuBarManagerDidRequestQuit(_ manager: MenuBarManager)
}

// MARK: - MenuBarManager

final class MenuBarManager: NSObject {

    // MARK: - Types

    enum Status {
        case normal
        case error(String)
    }

    struct RecentRecord {
        let title: String
        let date: Date
        let fileURL: URL
    }

    // MARK: - Properties

    weak var delegate: MenuBarManagerDelegate?

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.QuickNoteObsidian"
    private let logger = Logger(subsystem: MenuBarManager.subsystem, category: "MenuBarManager")
    private var statusItem: NSStatusItem?
    private var recentRecords: [RecentRecord] = []
    private let maxRecentRecords = 10

    // MARK: - Public

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "QuickNote")
            button.image?.isTemplate = true
        }

        rebuildMenu()
        logger.info("Menu bar setup complete")
    }

    func updateStatus(_ status: Status) {
        guard let button = statusItem?.button else { return }

        switch status {
        case .normal:
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "QuickNote")
        case .error(let message):
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: message)
            logger.warning("Status: \(message)")
        }
        button.image?.isTemplate = true
    }

    func addRecentRecord(title: String, fileURL: URL) {
        let record = RecentRecord(title: title, date: Date(), fileURL: fileURL)
        recentRecords.insert(record, at: 0)
        if recentRecords.count > maxRecentRecords {
            recentRecords.removeLast()
        }
        rebuildMenu()
    }

    // MARK: - Private

    private func rebuildMenu() {
        let menu = NSMenu()

        // 녹음 시작
        let recordItem = NSMenuItem(
            title: "녹음 시작 (⌃⌥⌘I)",
            action: #selector(recordAction),
            keyEquivalent: ""
        )
        recordItem.target = self
        menu.addItem(recordItem)

        menu.addItem(.separator())

        // 최근 기록
        if recentRecords.isEmpty {
            let emptyItem = NSMenuItem(title: "최근 기록 없음", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            let headerItem = NSMenuItem(title: "최근 기록", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"

            for (index, record) in recentRecords.enumerated() {
                let displayTitle = "\(formatter.string(from: record.date))  \(record.title)"
                let item = NSMenuItem(
                    title: displayTitle,
                    action: #selector(openRecentRecord(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // 종료
        let quitItem = NSMenuItem(title: "종료", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func recordAction() {
        delegate?.menuBarManagerDidRequestRecording(self)
    }

    @objc private func openRecentRecord(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index >= 0, index < recentRecords.count else { return }

        let record = recentRecords[index]
        let vaultPath = ConfigManager.shared.vaultPath
        let vaultName = URL(fileURLWithPath: vaultPath).lastPathComponent
        let relativePath = record.fileURL.path.replacingOccurrences(of: vaultPath + "/", with: "")

        // .md 확장자 제거 (Obsidian URI 규약)
        let pathWithoutExtension = relativePath.hasSuffix(".md")
            ? String(relativePath.dropLast(3))
            : relativePath

        guard let encodedVault = vaultName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedPath = pathWithoutExtension.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }

        if let url = URL(string: "obsidian://open?vault=\(encodedVault)&file=\(encodedPath)") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quitAction() {
        delegate?.menuBarManagerDidRequestQuit(self)
    }
}
