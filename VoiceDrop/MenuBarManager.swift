import AppKit
import os

// MARK: - MenuBarManagerDelegate

protocol MenuBarManagerDelegate: AnyObject {
    func menuBarManagerDidRequestChangeFolder(_ manager: MenuBarManager)
    func menuBarManagerDidRequestQuit(_ manager: MenuBarManager)
}

// MARK: - RecordItemView

/// 최근 기록 메뉴 아이템의 커스텀 뷰. 클릭=Finder에서 열기, ✕=노트 삭제.
private class RecordItemView: NSView {

    var onOpen: (() -> Void)?
    var onDelete: (() -> Void)?
    private var isHighlighted = false

    init(title: String) {
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 22))

        let label = NSTextField(labelWithString: title)
        label.frame = NSRect(x: 20, y: 1, width: 260, height: 20)
        label.font = NSFont.menuFont(ofSize: 14)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)

        let button = NSButton(frame: NSRect(x: 288, y: 1, width: 24, height: 20))
        button.title = "✕"
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.contentTintColor = .secondaryLabelColor
        button.target = self
        button.action = #selector(deleteClicked)
        button.toolTip = "노트 삭제"
        addSubview(button)

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            bounds.fill()
        }
        super.draw(dirtyRect)
    }

    override func mouseEntered(with event: NSEvent) {
        isHighlighted = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHighlighted = false
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        onOpen?()
        enclosingMenuItem?.menu?.cancelTracking()
    }

    @objc private func deleteClicked() {
        onDelete?()
    }
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

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.VoiceDrop"
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

    // MARK: - Menu

    func rebuildMenu() {
        let menu = NSMenu()

        // 안내 문구
        let infoItem = NSMenuItem(
            title: "SuperWhisper 녹음 → .md 노트 자동 저장",
            action: nil,
            keyEquivalent: ""
        )
        infoItem.isEnabled = false
        menu.addItem(infoItem)

        // 저장 폴더 표시 + 변경
        let folderPath = ConfigManager.shared.noteDirectoryURL.path
        let folderName = ConfigManager.shared.noteDirectoryURL.lastPathComponent
        let folderItem = NSMenuItem(
            title: "📁 \(folderName)",
            action: #selector(changeFolderAction),
            keyEquivalent: ""
        )
        folderItem.target = self
        folderItem.toolTip = folderPath
        menu.addItem(folderItem)

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
                let item = NSMenuItem()
                let view = RecordItemView(title: displayTitle)
                view.onOpen = { [weak self] in
                    guard let self, index < self.recentRecords.count else { return }
                    NSWorkspace.shared.activateFileViewerSelecting([self.recentRecords[index].fileURL])
                }
                view.onDelete = { [weak self] in
                    self?.deleteRecord(at: index)
                }
                item.view = view
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

    @objc private func changeFolderAction() {
        delegate?.menuBarManagerDidRequestChangeFolder(self)
    }

    private func deleteRecord(at index: Int) {
        guard index >= 0, index < recentRecords.count else { return }

        let record = recentRecords[index]

        // 파일 삭제
        do {
            try FileManager.default.removeItem(at: record.fileURL)
            logger.info("Deleted note: \(record.fileURL.lastPathComponent)")
        } catch {
            logger.error("Failed to delete: \(error.localizedDescription)")
        }

        // 목록에서 제거 + 메뉴 갱신
        recentRecords.remove(at: index)
        rebuildMenu()
    }

    @objc private func quitAction() {
        delegate?.menuBarManagerDidRequestQuit(self)
    }
}
