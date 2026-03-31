import AppKit

// MARK: - Entry Point

@main
enum App {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    private var appState: AppState!

    func applicationDidFinishLaunching(_ notification: Notification) {
        appState = AppState()
        appState.start()
    }
}
