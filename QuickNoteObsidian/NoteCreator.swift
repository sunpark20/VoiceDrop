import Foundation
import os

// MARK: - NoteCreator

enum NoteCreator {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.QuickNoteObsidian"
    private static let logger = Logger(subsystem: subsystem, category: "NoteCreator")

    static let maxTitleLength = 50
    private static let invalidFilenameCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")

    // MARK: - Types

    struct CreatedNote {
        let title: String
        let fileURL: URL
    }

    // MARK: - Public

    static func createNote(from result: RecordingResult, in directory: URL) -> CreatedNote? {
        let title = extractTitle(from: result.text)
        let body = buildBody(from: result)

        guard let fileURL = uniqueFileURL(title: title, in: directory) else {
            logger.error("Failed to create unique file URL for: \(title)")
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("Created note: \(fileURL.lastPathComponent)")
            return CreatedNote(title: title, fileURL: fileURL)
        } catch {
            logger.error("Failed to write note: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private

    private static func extractTitle(from text: String) -> String {
        let firstLine = text.components(separatedBy: .newlines).first ?? ""
        var sanitized = firstLine
            .unicodeScalars
            .filter { !invalidFilenameCharacters.contains($0) }
            .reduce(into: "") { $0.unicodeScalars.append($1) }
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HHmmss"
            return "음성메모_\(formatter.string(from: Date()))"
        }

        if sanitized.count > maxTitleLength {
            sanitized = String(sanitized.prefix(maxTitleLength)) + "…"
        }

        return sanitized
    }

    private static func buildBody(from result: RecordingResult) -> String {
        var lines: [String] = []

        // Frontmatter
        lines.append("---")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        lines.append("created: \(formatter.string(from: Date()))")
        lines.append("source: voice")
        if let mode = result.modeName {
            lines.append("mode: \(mode)")
        }
        lines.append("tags: [음성메모]")
        lines.append("---")
        lines.append("")
        lines.append(result.text)
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static func uniqueFileURL(title: String, in directory: URL) -> URL? {
        let baseURL = directory.appendingPathComponent(title).appendingPathExtension("md")

        if !FileManager.default.fileExists(atPath: baseURL.path) {
            return baseURL
        }

        for i in 2...99 {
            let numberedURL = directory
                .appendingPathComponent("\(title)_\(i)")
                .appendingPathExtension("md")
            if !FileManager.default.fileExists(atPath: numberedURL.path) {
                return numberedURL
            }
        }

        return nil
    }
}
