import AppKit
import ApplicationServices
import os

// MARK: - HotkeyManager

final class HotkeyManager {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.QuickNoteObsidian"
    private let logger = Logger(subsystem: HotkeyManager.subsystem, category: "HotkeyManager")

    // Strong reference — ARC 해제 방지 필수 (Ice 패턴)
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // Ctrl+Option+Cmd+I  ('i' key = keyCode 34)
    // keyCode 사용 필수 — characters는 한글 입력기에서 'ㅑ' 반환
    private let targetKeyCode: UInt16 = 34
    private let targetModifiers: NSEvent.ModifierFlags = [.control, .option, .command]

    var onHotkeyPressed: (() -> Void)?

    // MARK: - Lifecycle

    deinit {
        unregister()
    }

    // MARK: - Public

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// 접근성 권한을 확인하고, 없으면 시스템 설정 다이얼로그를 띄운다.
    @discardableResult
    func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func register() {
        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
            logger.warning("Accessibility permission not granted — global hotkey may not work")
        }

        // Global: 앱이 포커스가 아닐 때 캡처
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local: 앱이 포커스일 때 캡처
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        logger.info("Hotkey registered: Ctrl+Option+Cmd+I (keyCode \(self.targetKeyCode))")
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    // MARK: - Private

    private func handleKeyEvent(_ event: NSEvent) {
        guard event.keyCode == targetKeyCode else { return }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == targetModifiers else { return }

        logger.info("Hotkey triggered")
        onHotkeyPressed?()
    }
}
