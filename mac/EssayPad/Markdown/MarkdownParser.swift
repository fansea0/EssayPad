import Foundation
import SwiftUI
import AppKit

enum MarkdownParser {
    static func render(_ source: String) -> AttributedString {
        var out = AttributedString()
        let lines = source.components(separatedBy: "\n")
        var i = 0
        var inCodeBlock = false
        var codeLang = ""
        var codeBuffer: [String] = []
        var listBuffer: [(marker: String, content: String, level: Int)] = []
        var paragraphBuffer: [String] = []

        func flushParagraph() {
            guard !paragraphBuffer.isEmpty else { return }
            let joined = paragraphBuffer.joined(separator: " ")
            out.append(parseInline(joined))
            out.append(AttributedString("\n"))
            paragraphBuffer.removeAll(keepingCapacity: true)
        }

        func flushList() {
            guard !listBuffer.isEmpty else { return }
            for item in listBuffer {
                let indent = String(repeating: "  ", count: item.level)
                let prefix = "\(indent)\(item.marker) "
                var s = AttributedString(prefix)
                var body = parseInline(item.content)
                if item.marker == "[ ]" {
                    s.foregroundColor = .secondary
                    body = AttributedString("☐  ")
                    body.foregroundColor = .secondary
                } else if item.marker == "[x]" {
                    s.foregroundColor = .green
                    body = AttributedString("☑  ")
                    body.foregroundColor = .green
                }
                s.append(body)
                out.append(s)
                out.append(AttributedString("\n"))
            }
            listBuffer.removeAll(keepingCapacity: true)
        }

        while i < lines.count {
            let line = lines[i]

            if line.hasPrefix("```") {
                flushParagraph()
                flushList()
                if inCodeBlock {
                    out.append(renderCodeBlock(codeBuffer, lang: codeLang))
                    inCodeBlock = false
                    codeLang = ""
                    codeBuffer = []
                } else {
                    inCodeBlock = true
                    let rest = line.dropFirst(3)
                    codeLang = String(rest).trimmingCharacters(in: .whitespaces)
                }
                i += 1
                continue
            }

            if inCodeBlock {
                codeBuffer.append(line)
                i += 1
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                flushList()
                i += 1
                continue
            }

            if isHorizontalRule(trimmed) {
                flushParagraph()
                flushList()
                var hr = AttributedString("────────────────")
                hr.foregroundColor = .secondary
                out.append(hr)
                out.append(AttributedString("\n"))
                i += 1
                continue
            }

            if isTableRow(line), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flushParagraph()
                flushList()
                var tableLines: [String] = [line]
                var j = i + 2
                while j < lines.count, isTableRow(lines[j]) {
                    tableLines.append(lines[j])
                    j += 1
                }
                out.append(renderTable(tableLines))
                i = j
                continue
            }

            if let taskMarker = taskListMarker(trimmed) {
                flushParagraph()
                flushList()
                listBuffer.append((taskMarker, String(trimmed.dropFirst(taskMarker.count + 2)), 0))
                i += 1
                continue
            }

            if let listItem = unorderedListItem(trimmed) {
                flushParagraph()
                let (content, level) = listItem
                let marker = "•"
                listBuffer.append((marker, content, level))
                i += 1
                continue
            }

            if let quote = quoteLine(trimmed) {
                flushParagraph()
                flushList()
                let (content, level) = quote
                let bar = String(repeating: "│ ", count: level)
                let indent = String(repeating: " ", count: level * 2)
                var s = AttributedString("\(indent)\(bar)")
                let colors: [Color] = [.primary, .secondary, Color(white: 0.5), Color(white: 0.6)]
                s.foregroundColor = level <= colors.count ? colors[level - 1] : .secondary
                var body = parseInline(content)
                body.foregroundColor = level <= colors.count ? colors[level - 1] : .secondary
                body.font = .system(.body).italic()
                s.append(body)
                out.append(s)
                out.append(AttributedString("\n"))
                i += 1
                continue
            }

            if let h = heading(line) {
                flushParagraph()
                flushList()
                out.append(h)
                out.append(AttributedString("\n"))
                i += 1
                continue
            }

            if let img = imageLine(trimmed) {
                flushParagraph()
                flushList()
                var s = AttributedString("🖼  [图片: \(img)]")
                s.foregroundColor = .secondary
                s.font = .system(.body).italic()
                out.append(s)
                out.append(AttributedString("\n"))
                i += 1
                continue
            }

            flushList()
            paragraphBuffer.append(trimmed)
            i += 1
        }

        if inCodeBlock, !codeBuffer.isEmpty {
            out.append(renderCodeBlock(codeBuffer, lang: codeLang))
        } else {
            flushParagraph()
            flushList()
        }
        return out
    }

    private static func isHorizontalRule(_ s: String) -> Bool {
        guard s.count >= 3 else { return false }
        let chars = Set(s)
        guard chars.count == 1, chars.contains("-") || chars.contains("*") || chars.contains("_") else {
            return false
        }
        return s.allSatisfy { $0 == "-" || $0 == "*" || $0 == "_" }
    }

    private static func isTableRow(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|"), t.hasSuffix("|"), t.count > 2 else { return false }
        return t.contains("|")
    }

    private static func isTableSeparator(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|"), t.hasSuffix("|") else { return false }
        let inner = t.dropFirst().dropLast()
        let cells = inner.split(separator: "|", omittingEmptySubsequences: false)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            return trimmed.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private static func taskListMarker(_ s: String) -> String? {
        let lower = s.lowercased()
        if lower.hasPrefix("- [ ] ") || lower == "- [ ]" { return "[ ]" }
        if lower.hasPrefix("- [x] ") || lower == "- [x]" { return "[x]" }
        if lower.hasPrefix("* [ ] ") || lower == "* [ ]" { return "[ ]" }
        if lower.hasPrefix("* [x] ") || lower == "* [x]" { return "[x]" }
        return nil
    }

    private static func unorderedListItem(_ s: String) -> (String, Int)? {
        var level = 0
        var rest = Substring(s)
        while rest.hasPrefix("  ") || rest.hasPrefix("\t") {
            level += 1
            rest = rest.dropFirst().drop(while: { $0 == " " || $0 == "\t" })
            rest = rest.drop(while: { $0 == " " || $0 == "\t" })
        }
        if rest.hasPrefix("- ") {
            return (String(rest.dropFirst(2)), level)
        }
        if rest.hasPrefix("* ") {
            return (String(rest.dropFirst(2)), level)
        }
        if rest.hasPrefix("+ ") {
            return (String(rest.dropFirst(2)), level)
        }
        return nil
    }

    private static func quoteLine(_ s: String) -> (String, Int)? {
        var level = 0
        var rest = Substring(s)
        while rest.hasPrefix(">") {
            level += 1
            rest = rest.dropFirst()
            if rest.hasPrefix(" ") { rest = rest.dropFirst() }
        }
        guard level >= 1, !rest.isEmpty else { return nil }
        return (String(rest), level)
    }

    private static func imageLine(_ s: String) -> String? {
        let pattern = "!\\[([^\\]]*)\\]\\(([^)]+)\\)"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 2 else { return nil }
        let altRange = m.range(at: 1)
        guard altRange.location != NSNotFound else { return nil }
        let alt = ns.substring(with: altRange)
        return alt.isEmpty ? "图片" : alt
    }

    private static func renderCodeBlock(_ lines: [String], lang: String) -> AttributedString {
        let body = lines.joined(separator: "\n")
        let ns = NSMutableAttributedString()
        if !lang.isEmpty {
            let langAttr = NSMutableAttributedString(string: lang)
            langAttr.addAttributes([
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
                .backgroundColor: NSColor.controlBackgroundColor
            ], range: NSRange(location: 0, length: langAttr.length))
            let chip = NSMutableAttributedString(string: " ")
            chip.append(langAttr)
            chip.append(NSAttributedString(string: "\n"))
            chip.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: 0, length: chip.length))
            ns.append(chip)
        }
        let codeAttr = NSMutableAttributedString(string: body)
        codeAttr.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.gray.withAlphaComponent(0.10)
        ], range: NSRange(location: 0, length: codeAttr.length))
        ns.append(codeAttr)
        var result = AttributedString(ns)
        result.foregroundColor = .primary
        result.append(AttributedString("\n"))
        return result
    }

    private static func renderTable(_ lines: [String]) -> AttributedString {
        let header = parseTableRow(lines[0])
        let rows = lines.dropFirst().map { parseTableRow($0) }
        let colCount = max(header.count, rows.map { $0.count }.max() ?? 0)
        guard colCount > 0 else { return AttributedString("") }
        let widths: [Int] = (0..<colCount).map { c in
            let vals = ([header] + rows).map { $0.indices.contains(c) ? $0[c].count : 0 }
            return max(vals.max() ?? 3, 3)
        }

        var out = AttributedString()

        var headerLine = "|"
        var sepLine = "|"
        for c in 0..<colCount {
            let w = widths[c]
            let cell = (c < header.count ? header[c] : "")
            headerLine += " \(cell.padding(toLength: w, withPad: " ", startingAt: 0)) |"
            sepLine += " \(String(repeating: "─", count: w)) |"
        }
        var hl = AttributedString(headerLine)
        hl.font = .system(.body, design: .monospaced).bold()
        hl.foregroundColor = .primary
        out.append(hl)
        out.append(AttributedString("\n"))

        var sl = AttributedString(sepLine)
        sl.font = .system(.body, design: .monospaced)
        sl.foregroundColor = .secondary
        out.append(sl)
        out.append(AttributedString("\n"))

        for row in rows {
            var line = "|"
            for c in 0..<colCount {
                let w = widths[c]
                let cell = (c < row.count ? row[c] : "")
                line += " \(cell.padding(toLength: w, withPad: " ", startingAt: 0)) |"
            }
            var rl = AttributedString(line)
            rl.font = .system(.body, design: .monospaced)
            rl.foregroundColor = .primary
            out.append(rl)
            out.append(AttributedString("\n"))
        }
        return out
    }

    private static func parseTableRow(_ s: String) -> [String] {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func heading(_ line: String) -> AttributedString? {
        var level = 0
        var raw = line
        while raw.hasPrefix("#") {
            level += 1
            raw.removeFirst()
        }
        guard level >= 1, level <= 6, raw.first == " " else { return nil }
        let text = String(raw.dropFirst())
        var s = AttributedString(text)
        let sizes: [CGFloat] = [28, 24, 20, 18, 16, 15]
        s.font = .system(size: sizes[level - 1], weight: .bold)
        return s
    }

    private static func parseInline(_ line: String) -> AttributedString {
        var s = AttributedString(line)
        apply(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)", in: &s) { m in
            var r = m
            r.foregroundColor = .secondary
            r.font = .system(.body).italic()
            return r
        }
        apply(pattern: "`([^`]+)`", in: &s) { m in
            var r = m
            r.font = .system(.body, design: .monospaced)
            r.foregroundColor = .accentColor
            return r
        }
        apply(pattern: "\\*\\*([^*]+)\\*\\*", in: &s) { m in
            var r = m
            r.font = .system(.body).bold()
            return r
        }
        apply(pattern: "__([^_]+)__", in: &s) { m in
            var r = m
            r.font = .system(.body).bold()
            return r
        }
        apply(pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)", in: &s) { m in
            var r = m
            r.font = .system(.body).italic()
            return r
        }
        apply(pattern: "(?<!_)_([^_]+)_(?!_)", in: &s) { m in
            var r = m
            r.font = .system(.body).italic()
            return r
        }
        apply(pattern: "~~([^~]+)~~", in: &s) { m in
            var r = m
            r.strikethroughStyle = .single
            r.foregroundColor = .secondary
            return r
        }
        apply(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", in: &s) { m in
            var r = m
            r.foregroundColor = .accentColor
            r.underlineStyle = .single
            return r
        }
        return s
    }

    private static func apply(
        pattern: String,
        in s: inout AttributedString,
        transform: (AttributedString) -> AttributedString
    ) {
        let plain = String(s.characters[...])
        guard let re = try? NSRegularExpression(pattern: pattern) else { return }
        let ns = plain as NSString
        var offset = 0
        re.enumerateMatches(in: plain, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let m = match else { return }
            let nsRange = NSRange(location: m.range.location + offset, length: m.range.length)
            guard let attrRange = Range(nsRange, in: s) else { return }
            let attrSub = AttributedString(s[attrRange])
            let transformed = transform(attrSub)
            let oldLen = attrSub.characters.count
            let newLen = transformed.characters.count
            offset += newLen - oldLen
            s.replaceSubrange(attrRange, with: transformed)
        }
    }
}