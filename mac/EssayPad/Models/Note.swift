import Foundation

struct Note: Codable, Identifiable, Hashable {
    let id: Int64
    var category: Int
    var title: String
    var content: String
    let createdAt: Int64
    var updatedAt: Int64
    var taskId: Int64

    enum CodingKeys: String, CodingKey {
        case id, category, title, content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case taskId = "task_id"
    }

    var categoryEnum: NoteCategory { NoteCategory(rawValue: category) ?? .idea }

    func toMarkdown() -> String {
        var out = title.isEmpty ? "" : "# \(title)"
        if !content.isEmpty {
            if !out.isEmpty { out += "\n\n" }
            out += content
        }
        if !out.hasSuffix("\n") { out += "\n" }
        return out
    }

    func toPlainText() -> String {
        let joined: String
        if title.isEmpty && content.isEmpty {
            joined = ""
        } else if title.isEmpty {
            joined = content
        } else if content.isEmpty {
            joined = title
        } else {
            joined = "\(title)\n\n\(content)"
        }
        var result = joined
        if let regex1 = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*") {
            result = regex1.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }
        if let regex2 = try? NSRegularExpression(pattern: "\\*(.+?)\\*") {
            result = regex2.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }
        if let regex3 = try? NSRegularExpression(pattern: "`([^`]+)`") {
            result = regex3.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }
        if let regex4 = try? NSRegularExpression(pattern: "~~(.+?)~~") {
            result = regex4.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }
        if let regex5 = try? NSRegularExpression(pattern: "^#{1,6}\\s+", options: .anchorsMatchLines) {
            result = regex5.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        if let regex6 = try? NSRegularExpression(pattern: "^>\\s+", options: .anchorsMatchLines) {
            result = regex6.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        if let regex7 = try? NSRegularExpression(pattern: "^\\s*[-*+]\\s+", options: .anchorsMatchLines) {
            result = regex7.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        return result
    }
}