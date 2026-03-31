import Foundation
import os

// MARK: - RecordingResult

struct RecordingResult {
    let text: String
    let rawText: String?
    let datetime: String?
    let modeName: String?
    let duration: Int?
}

// MARK: - MetaJSONParser

enum MetaJSONParser {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.sunguk.QuickNoteObsidian"
    private static let logger = Logger(subsystem: subsystem, category: "MetaJSONParser")

    /// meta.json을 파싱하여 RecordingResult를 반환한다.
    /// result → rawResult 순으로 폴백. 둘 다 없거나 비어있으면 nil 반환 (crash 금지).
    static func parse(fileURL: URL) -> RecordingResult? {
        guard let data = try? Data(contentsOf: fileURL) else {
            logger.error("Failed to read meta.json: \(fileURL.path)")
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.error("Failed to parse JSON: \(fileURL.path)")
            return nil
        }

        let result = json["result"] as? String
        let rawResult = json["rawResult"] as? String

        guard let text = result ?? rawResult, !text.isEmpty else {
            logger.warning("Empty result in meta.json: \(fileURL.path)")
            return nil
        }

        return RecordingResult(
            text: text,
            rawText: rawResult,
            datetime: json["datetime"] as? String,
            modeName: json["modeName"] as? String,
            duration: json["duration"] as? Int
        )
    }
}
