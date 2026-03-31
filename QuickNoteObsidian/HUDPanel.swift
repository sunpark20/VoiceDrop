import AppKit
import os

// MARK: - HUDPanel

final class HUDPanel: NSObject {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.QuickNoteObsidian"
    private let logger = Logger(subsystem: HUDPanel.subsystem, category: "HUDPanel")

    private var window: NSWindow?
    private var dismissTimer: Timer?
    private let displayDuration: TimeInterval = 4.0

    // MARK: - Public

    func show(text: String, title: String) {
        dismiss()

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = title
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)

        // 텍스트 뷰 (스크롤 가능)
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 200))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.string = text
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        panel.contentView = scrollView

        // 화면 우상단 위치
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let x = screenFrame.maxX - panelFrame.width - 16
            let y = screenFrame.maxY - panelFrame.height - 16
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // 클릭하면 닫기
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        panel.contentView?.addGestureRecognizer(clickGesture)

        panel.orderFront(nil)
        self.window = panel

        // 자동 닫기 타이머
        dismissTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }

        logger.info("HUD shown: \(title)")
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        // orderOut 사용 — close()는 release 트리거로 dangling pointer 위험
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Private

    @objc private func handleClick() {
        dismiss()
    }
}
