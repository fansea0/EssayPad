import SwiftUI
import AppKit

// MARK: - Custom NSTextView with Markdown Keyboard Shortcuts

final class MarkdownTextView: NSTextView {

    /// Intercept Cmd‑key combos **before** the menu / rich‑text system consumes them.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ----- Cmd only -----
        if flags == .command {
            NSLog("[ES] MarkdownTextView performKeyEquivalent Cmd+\(chars)")
            switch chars {
            case "b": toggleWrap("**"); return true
            case "i": toggleWrap("*");   return true
            case "k": insertLink();      return true
            case "u": toggleWrap("~~");  return true
            default:  break
            }
        }

        // ----- Cmd + Shift -----
        if flags == [.command, .shift] {
            NSLog("[ES] MarkdownTextView performKeyEquivalent Cmd+Shift+\(chars)")
            switch chars {
            case "k": toggleWrap("`");   return true
            case "h": toggleHeading2();  return true
            default:  break
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Shortcut Actions

    private func toggleWrap(_ marker: String) {
        guard let storage = textStorage, let um = undoManager else { return }
        let sel = selectedRange()
        let nsStr = storage.string as NSString
        let m = (marker as NSString).length

        um.beginUndoGrouping()

        if sel.length > 0 {
            // ----- existing selection: toggle wrap / unwrap -----
            let leftLoc  = sel.location - m
            let rightLoc = sel.location + sel.length

            // already wrapped?
            if leftLoc >= 0, rightLoc + m <= nsStr.length,
               nsStr.substring(with: NSRange(location: leftLoc, length: m)) == marker,
               nsStr.substring(with: NSRange(location: rightLoc, length: m)) == marker {
                // unwrap
                storage.replaceCharacters(in: NSRange(location: rightLoc, length: m), with: "")
                storage.replaceCharacters(in: NSRange(location: leftLoc, length: m), with: "")
                um.endUndoGrouping()
                setSelectedRange(NSRange(location: leftLoc, length: sel.length))
                return
            }

            // wrap
            storage.replaceCharacters(in: NSRange(location: sel.location + sel.length, length: 0), with: marker)
            storage.replaceCharacters(in: NSRange(location: sel.location, length: 0), with: marker)
            um.endUndoGrouping()
            setSelectedRange(NSRange(location: sel.location, length: sel.length + 2 * m))

        } else {
            // ----- no selection: insert empty markers -----
            storage.replaceCharacters(in: sel, with: marker + marker)
            um.endUndoGrouping()
            setSelectedRange(NSRange(location: sel.location + m, length: 0))
        }
    }

    private func insertLink() {
        guard let storage = textStorage, let um = undoManager else { return }
        let sel = selectedRange()
        let nsStr = storage.string as NSString

        um.beginUndoGrouping()

        if sel.length > 0 {
            let text = nsStr.substring(with: sel)
            storage.replaceCharacters(in: sel, with: "[\(text)]()")
            um.endUndoGrouping()
            // cursor between the parens: [text](|)
            setSelectedRange(NSRange(location: sel.location + text.count + 3, length: 0))
        } else {
            storage.replaceCharacters(in: sel, with: "[]()")
            um.endUndoGrouping()
            // cursor inside the brackets: [|]()
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
        }
    }

    /// Toggle "## " at start of current line (heading level 2).
    private func toggleHeading2() {
        guard let storage = textStorage, let um = undoManager else { return }
        let sel = selectedRange()
        let nsStr = storage.string as NSString
        let len = nsStr.length

        // Find line start
        var lineStart = sel.location
        while lineStart > 0 {
            if nsStr.character(at: lineStart - 1) == UInt16(UnicodeScalar("\n").value) { break }
            lineStart -= 1
        }
        // Guard against out-of-bounds
        let maxPrefix = min(3, len - lineStart)
        guard maxPrefix > 0 else { return }

        let prefix = nsStr.substring(with: NSRange(location: lineStart, length: maxPrefix))

        um.beginUndoGrouping()
        if prefix == "## " {
            storage.replaceCharacters(in: NSRange(location: lineStart, length: 3), with: "")
        } else {
            storage.replaceCharacters(in: NSRange(location: lineStart, length: 0), with: "## ")
        }
        um.endUndoGrouping()
    }

    // MARK: - Image Paste Handling

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        let supportedTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        let bestType = pasteboard.availableType(from: supportedTypes)
        NSLog("[ES] MarkdownTextView paste bestType=\(bestType?.rawValue ?? "nil")")

        // 1) Direct image data (screenshot, browser copy-image)
        if let type = bestType,
           let imageData = pasteboard.data(forType: type),
           let image = NSImage(data: imageData) {
            insertImageMarkdown(image: image, data: imageData)
            return
        }

        // 2) File URL pointing to an image file (Finder copy)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first,
           ImagePasteHelper.isImageFile(url),
           let image = NSImage(contentsOf: url),
           let fileData = try? Data(contentsOf: url) {
            insertImageMarkdown(image: image, data: fileData)
            return
        }

        // 3) Fallback: default paste for plain-text / rich-text
        super.paste(sender)
    }

    private func insertImageMarkdown(image: NSImage, data: Data) {
        guard let imageDir = ImagePasteHelper.ensureImageDir() else {
            NSLog("[ES] insertImageMarkdown FAIL: cannot ensure image dir")
            super.paste(nil)
            return
        }

        // Resize for inline display before saving
        let maxW = min(ImagePasteHelper.usableTextWidth(for: self), ImagePasteHelper.inlineMaxWidthCap)
        let displayImage = ImagePasteHelper.resizeImage(image, maxWidth: maxW)

        guard let pngData = ImagePasteHelper.toPNGData(from: displayImage) else {
            NSLog("[ES] insertImageMarkdown FAIL: cannot convert to PNG")
            super.paste(nil)
            return
        }

        let filename = "\(UUID().uuidString).png"
        let fileURL = imageDir.appendingPathComponent(filename)

        do {
            try pngData.write(to: fileURL)
        } catch {
            NSLog("[ES] insertImageMarkdown FAIL writing image: \(error)")
            super.paste(nil)
            return
        }

        // Reload from disk to get a clean NSImage for the attachment cell
        guard let loaded = NSImage(contentsOf: fileURL) else {
            NSLog("[ES] insertImageMarkdown FAIL: cannot reload saved image")
            super.paste(nil)
            return
        }

        let cell = NSTextAttachmentCell()
        cell.image = loaded
        let attachment = NSTextAttachment()
        attachment.attachmentCell = cell
        attachment.bounds = NSRect(origin: .zero, size: loaded.size)

        let relPath = "images/\(filename)"
        let attrStr = NSMutableAttributedString(attachment: attachment)
        attrStr.addAttribute(NSAttributedString.Key.imageMarkdownPath, value: relPath,
                             range: NSRange(location: 0, length: attrStr.length))
        attrStr.append(NSAttributedString(string: "\n"))

        let sel = selectedRange()
        textStorage?.replaceCharacters(in: sel, with: attrStr)
        didChangeText()
        NSLog("[ES] insertImageMarkdown OK \(relPath) size=\(loaded.size)")
    }

    // MARK: - Image Preview (click to open full-size)

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)

        // Check if the click lands on an image attachment
        if index > 0, let storage = textStorage {
            let effectiveRange = NSRange(location: index - 1, length: 1)
            if effectiveRange.location + effectiveRange.length <= storage.length,
               let path = storage.attribute(.imageMarkdownPath, at: effectiveRange.location,
                                            effectiveRange: nil) as? String {
                ImagePasteHelper.openInPreview(path: path)
                return
            }
        }

        // Fallback: normal click behavior
        super.mouseDown(with: event)
    }
}

// MARK: - SwiftUI Bridge

struct MarkdownStyledEditor: NSViewRepresentable {
    var text: String
    var onTextChange: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = MarkdownTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 0))
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: 14)
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.allowsDocumentBackgroundColorChange = false
        textView.textContainerInset = NSSize(width: 0, height: 12)
        textView.textContainer?.lineFragmentPadding = 28
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor,
        ]

        scrollView.documentView = textView

        applyMarkdownStyles(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Keep coordinator's closure in sync in case parent rebuilt with new capture
        context.coordinator.onTextChange = onTextChange
        if textView.string != text {
            // 编辑器正在被聚焦编辑时,以编辑器内容为准,避免回写滞后的 text 覆盖用户最新输入(快速打字丢字)
            let isEditing = textView.window?.firstResponder === textView
            guard !isEditing else { return }
            context.coordinator.isUpdatingFromSwiftUI = true
            textView.string = text
            // Restore NSTextAttachments for ![](images/...) patterns
            ImagePasteHelper.restoreImageAttachments(in: textView)
            context.coordinator.isUpdatingFromSwiftUI = false
            applyMarkdownStyles(to: textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextChange: onTextChange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onTextChange: (String) -> Void
        var isUpdatingFromSwiftUI = false
        private var pendingFormat: DispatchWorkItem?

        init(onTextChange: @escaping (String) -> Void) {
            self.onTextChange = onTextChange
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI else { return }
            guard let textView = notification.object as? NSTextView else {
                NSLog("[ES] textDidChange: no textView")
                return
            }
            // Build plain-text for save: attachments → ![](path)
            let saveText = ImagePasteHelper.markdownTextForSave(from: textView)
            NSLog("[ES] StyledEditor textDidChange save_len=\(saveText.count)")
            onTextChange(saveText)
            NSLog("[ES] StyledEditor onTextChange fired save_len=\(saveText.count)")

            pendingFormat?.cancel()
            let work = DispatchWorkItem { [weak textView] in
                guard let tv = textView else { return }
                let before = tv.string.count
                applyMarkdownStyles(to: tv)
                var boldChars = 0
                var monoChars = 0
                var italicChars = 0
                var fadedChars = 0
                if let storage = tv.textStorage {
                    let storageLen = storage.length
                    let fullRange = NSRange(location: 0, length: storageLen)
                    storage.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                        guard let f = value as? NSFont else { return }
                        if f.fontDescriptor.symbolicTraits.contains(.bold) {
                            boldChars += range.length
                        }
                        if f.fontDescriptor.symbolicTraits.contains(.italic) {
                            italicChars += range.length
                        }
                        if f.isFixedPitch {
                            monoChars += range.length
                        }
                    }
                    storage.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
                        if let c = value as? NSColor, c == NSColor.tertiaryLabelColor {
                            fadedChars += range.length
                        }
                    }
                }
                NSLog("[ES] styled len=\(before) bold_chars=\(boldChars) italic_chars=\(italicChars) mono_chars=\(monoChars) faded_chars=\(fadedChars)")
            }
            pendingFormat = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
        }
    }
}

@inline(__always)
private func baseFont(of size: CGFloat = 14, weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}

@inline(__always)
private func italicFont(of size: CGFloat = 14) -> NSFont {
    NSFontManager.shared.convert(baseFont(of: size), toHaveTrait: .italicFontMask)
}

@inline(__always)
private func monoFont(of size: CGFloat = 12) -> NSFont {
    NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
}

private func defaultAttributes() -> [NSAttributedString.Key: Any] {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 6
    paragraph.paragraphSpacing = 4
    paragraph.defaultTabInterval = 28
    paragraph.tabStops = []
    return [
        .font: baseFont(),
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: paragraph,
        .kern: 0.0,
    ]
}

func applyMarkdownStyles(to textView: NSTextView) {
    guard let storage = textView.textStorage else { return }
    let len = storage.length
    guard len > 0 else {
        storage.beginEditing()
        storage.setAttributes(defaultAttributes(), range: NSRange(location: 0, length: 0))
        storage.endEditing()
        return
    }
    let plain = storage.string
    let fullRange = NSRange(location: 0, length: len)

    let selectedRange = textView.selectedRange

    // Collect attachment ranges so we can skip them during the style reset.
    var excludeRanges: [NSRange] = []
    storage.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
        if value is NSTextAttachment { excludeRanges.append(range) }
    }
    excludeRanges.sort { $0.location < $1.location }

    storage.beginEditing()

    // Apply default attributes only on non-attachment ranges.
    var pos = 0
    for r in excludeRanges {
        if r.location > pos {
            let gap = NSRange(location: pos, length: r.location - pos)
            if gap.location + gap.length <= storage.length {
                storage.setAttributes(defaultAttributes(), range: gap)
            }
        }
        pos = NSMaxRange(r)
    }
    if pos < len {
        let tail = NSRange(location: pos, length: len - pos)
        if tail.location + tail.length <= storage.length {
            storage.setAttributes(defaultAttributes(), range: tail)
        }
    }

    applyBlockStyles(to: storage, in: plain)
    applyInlineStyles(to: storage, in: plain)
    applyFencedCodeBlocks(to: storage, in: plain)
    applyMarkerFade(to: storage, in: plain)

    storage.endEditing()

    if selectedRange.location <= len {
        textView.selectedRange = selectedRange
    }
}

private func applyBlockStyles(to storage: NSTextStorage, in plain: String) {
    let lines = plain.components(separatedBy: "\n")
    var offset = 0
    for line in lines {
        let nsLine = line as NSString
        let lineLen = nsLine.length
        let lineRange = NSRange(location: offset, length: lineLen)

        if lineRange.location + lineRange.length > storage.length { break }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            offset += lineLen + 1
            continue
        }

        if let (level, body) = parseHeading(line) {
            let sizes: [CGFloat] = [25, 21, 18, 16, 14, 13]
            let size = sizes[max(0, min(level - 1, 5))]
            let bodyStartInLine = line.count - body.count
            let bodyRange = NSRange(
                location: lineRange.location + bodyStartInLine,
                length: body.count
            )
            if bodyRange.location + bodyRange.length <= storage.length {
                storage.addAttribute(.font,
                                     value: baseFont(of: size, weight: .bold),
                                     range: bodyRange)
            }
            offset += lineLen + 1
            continue
        }

        if line.hasPrefix("```") {
            storage.addAttribute(.font, value: monoFont(of: 12),
                                 range: lineRange)
            storage.addAttribute(.foregroundColor,
                                 value: NSColor.tertiaryLabelColor,
                                 range: lineRange)
            offset += lineLen + 1
            continue
        }

        if trimmed.count >= 3 &&
            trimmed.allSatisfy({ $0 == "-" || $0 == "*" || $0 == "_" }) {
            storage.addAttribute(.foregroundColor,
                                 value: NSColor.tertiaryLabelColor,
                                 range: lineRange)
            offset += lineLen + 1
            continue
        }

        if line.hasPrefix("> ") || line.hasPrefix(">") {
            storage.addAttribute(.foregroundColor,
                                 value: NSColor.secondaryLabelColor,
                                 range: lineRange)
            storage.addAttribute(.font, value: italicFont(of: 16),
                                 range: lineRange)
            offset += lineLen + 1
            continue
        }

        if let (body, checked) = parseTaskItem(line) {
            let bodyStartInLine = line.count - body.count
            let bodyRange = NSRange(
                location: lineRange.location + bodyStartInLine,
                length: body.count
            )
            let markerLen = line.count - body.count
            let markerRange = NSRange(
                location: lineRange.location,
                length: markerLen
            )
            storage.addAttribute(.font,
                                 value: baseFont(of: 14, weight: .semibold),
                                 range: markerRange)
            storage.addAttribute(.foregroundColor,
                                 value: NSColor.systemBlue,
                                 range: markerRange)
            if bodyRange.location + bodyRange.length <= storage.length {
                if checked {
                    storage.addAttribute(.foregroundColor,
                                         value: NSColor.tertiaryLabelColor,
                                         range: bodyRange)
                    storage.addAttribute(.strikethroughStyle,
                                         value: NSUnderlineStyle.single.rawValue,
                                         range: bodyRange)
                }
            }
            offset += lineLen + 1
            continue
        }

        if isListItem(line) {
            let markerLen = markerLength(in: line)
            if markerLen > 0 {
                let markerRange = NSRange(location: lineRange.location,
                                          length: markerLen)
                storage.addAttribute(.foregroundColor,
                                     value: NSColor.systemBlue,
                                     range: markerRange)
                storage.addAttribute(.font,
                                     value: baseFont(of: 14, weight: .semibold),
                                     range: markerRange)
            }
            offset += lineLen + 1
            continue
        }

        offset += lineLen + 1
    }
}

private func applyInlineStyles(to storage: NSTextStorage, in plain: String) {
    let fullRange = NSRange(location: 0, length: (plain as NSString).length)

    applyRegex(in: plain, range: fullRange, pattern: #"\*\*([^*\n]+)\*\*"#) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.font,
                             value: baseFont(of: 14, weight: .bold),
                             range: r)
    }

    applyRegex(in: plain, range: fullRange,
               pattern: #"(?<![\*\\])(\*)([^*\n]+)\1(?!\*)"#) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.font,
                             value: italicFont(of: 14),
                             range: r)
    }

    applyRegex(in: plain, range: fullRange, pattern: #"`([^`\n]+)`"#) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.font,
                             value: monoFont(of: 12),
                             range: r)
        storage.addAttribute(.backgroundColor,
                             value: NSColor.quaternaryLabelColor
                                .withAlphaComponent(0.3),
                             range: r)
    }

    applyRegex(in: plain, range: fullRange,
               pattern: #"\[([^\]\n]+)\]\(([^)\n]+)\)"#) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.foregroundColor,
                             value: NSColor.linkColor,
                             range: r)
        storage.addAttribute(.underlineStyle,
                             value: NSUnderlineStyle.single.rawValue,
                             range: r)
    }

    applyRegex(in: plain, range: fullRange, pattern: #"~~([^~\n]+)~~"#) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.strikethroughStyle,
                             value: NSUnderlineStyle.single.rawValue,
                             range: r)
    }
}

private func applyFencedCodeBlocks(to storage: NSTextStorage, in plain: String) {
    let lines = plain.components(separatedBy: "\n")
    var offset = 0
    var inFence = false
    let f = monoFont(of: 12)
    let bg = NSColor.tertiaryLabelColor.withAlphaComponent(0.15)
    for line in lines {
        let nsLine = line as NSString
        let len = nsLine.length
        if line.hasPrefix("```") {
            inFence.toggle()
            offset += len + 1
            continue
        }
        if inFence {
            let r = NSRange(location: offset, length: len)
            if r.location + r.length <= storage.length {
                storage.addAttribute(.font, value: f, range: r)
                storage.addAttribute(.backgroundColor, value: bg, range: r)
                storage.addAttribute(.foregroundColor,
                                     value: NSColor.secondaryLabelColor,
                                     range: r)
            }
        }
        offset += len + 1
    }
}

private func parseHeading(_ line: String) -> (Int, String)? {
    var level = 0
    var s = Substring(line)
    while s.first == "#" { level += 1; s = s.dropFirst() }
    guard level >= 1, level <= 6 else { return nil }
    guard s.first == " " else { return nil }
    let body = s.dropFirst()
    if body.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
    return (level, String(body))
}

private func isListItem(_ line: String) -> Bool {
    if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
        return true
    }
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return false }
    var idx = trimmed.startIndex
    while idx < trimmed.endIndex, trimmed[idx].isNumber {
        idx = trimmed.index(after: idx)
    }
    guard idx < trimmed.endIndex, trimmed[idx] == "." else { return false }
    let next = trimmed.index(after: idx)
    guard next < trimmed.endIndex, trimmed[next] == " " else { return false }
    let digitCount = trimmed.distance(from: trimmed.startIndex, to: idx)
    return digitCount >= 1 && digitCount <= 3
}

private func markerLength(in line: String) -> Int {
    if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
        return 2
    }
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return 0 }
    var idx = trimmed.startIndex
    while idx < trimmed.endIndex, trimmed[idx].isNumber {
        idx = trimmed.index(after: idx)
    }
    guard idx < trimmed.endIndex, trimmed[idx] == "." else { return 0 }
    let next = trimmed.index(after: idx)
    guard next < trimmed.endIndex, trimmed[next] == " " else { return 0 }
    let prefix = String(trimmed[trimmed.startIndex...next])
    if let leading = line.range(of: prefix) {
        return line.distance(from: line.startIndex, to: leading.lowerBound) + prefix.count
    }
    return prefix.count
}

private func parseTaskItem(_ line: String) -> (String, Bool)? {
    let lower = line.lowercased()
    if lower.hasPrefix("- [ ] ") {
        let body = String(line.dropFirst(6))
        if !body.isEmpty { return (body, false) }
    }
    if lower.hasPrefix("- [x] ") {
        let body = String(line.dropFirst(6))
        if !body.isEmpty { return (body, true) }
    }
    return nil
}

private func applyRegex(
    in plain: String,
    range: NSRange,
    pattern: String,
    options: NSRegularExpression.Options = [],
    action: (NSRange) -> Void
) {
    guard let re = try? NSRegularExpression(pattern: pattern, options: options) else {
        NSLog("[ES] applyRegex: bad pattern \(pattern)")
        return
    }
    let matches = re.matches(in: plain, range: range)
    for m in matches {
        action(m.range)
    }
}

private func applyMarkerFade(to storage: NSTextStorage, in plain: String) {
    let ns = plain as NSString
    let fullRange = NSRange(location: 0, length: ns.length)
    let markerColor = NSColor.tertiaryLabelColor

    // ** (bold marker)
    applyRegex(in: plain, range: fullRange, pattern: #"\*\*"#) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.foregroundColor, value: markerColor, range: r)
    }

    // * 单星号 (italic marker, non-** and non-escaped)
    applyRegex(in: plain, range: fullRange,
               pattern: #"(?<![\*\\])\*(?!\*)"#) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.foregroundColor, value: markerColor, range: r)
    }

    // ` (inline code marker)
    applyRegex(in: plain, range: fullRange, pattern: #"`"#) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.foregroundColor, value: markerColor, range: r)
    }

    // 标题开头的 # 1~6 + 空格
    applyRegex(in: plain, range: fullRange,
               pattern: #"^#{1,6} "#,
               options: .anchorsMatchLines) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.foregroundColor, value: markerColor, range: r)
    }

    // 引用 >
    applyRegex(in: plain, range: fullRange,
               pattern: #"^> "#,
               options: .anchorsMatchLines) { r in
        guard r.location + r.length <= storage.length else { return }
        storage.addAttribute(.foregroundColor, value: markerColor, range: r)
    }
}
