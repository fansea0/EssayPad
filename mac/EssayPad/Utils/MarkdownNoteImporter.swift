import Foundation

enum MarkdownNoteImporter {
    struct ImportedNote: Equatable {
        let title: String
        let content: String
    }

    enum ImportError: LocalizedError {
        case unreadable(URL)

        var errorDescription: String? {
            switch self {
            case .unreadable(let url):
                return "无法读取 \(url.lastPathComponent)"
            }
        }
    }

    static func load(url: URL) throws -> ImportedNote {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        guard let text = decode(data) else {
            throw ImportError.unreadable(url)
        }
        return parse(markdown: text, fallbackTitle: url.deletingPathExtension().lastPathComponent)
    }

    static func parse(markdown: String, fallbackTitle: String) -> ImportedNote {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        if let titleIndex = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ")
        }) {
            let title = lines[titleIndex]
                .trimmingCharacters(in: .whitespaces)
                .dropFirst(2)
                .trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                var bodyLines = lines
                bodyLines.remove(at: titleIndex)
                let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                return ImportedNote(title: title, content: body)
            }
        }

        let title = fallbackTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return ImportedNote(
            title: title.isEmpty ? "导入笔记" : title,
            content: normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func decode(_ data: Data) -> String? {
        for encoding in [String.Encoding.utf8, .unicode, .utf16LittleEndian, .utf16BigEndian] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return nil
    }
}
