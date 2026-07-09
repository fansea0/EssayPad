import AppKit

extension NSAttributedString.Key {
    static let imageMarkdownPath = NSAttributedString.Key("EssayPad.imageMarkdownPath")
}

enum ImagePasteHelper {
    static let inlineMaxWidthCap: CGFloat = 720

    static func ensureImageDir() -> URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = support.appendingPathComponent("EssayPad", isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            NSLog("[ES] ImagePasteHelper ensureImageDir FAIL: \(error)")
            return nil
        }
    }

    static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "tiff", "heic", "webp"].contains(ext)
    }

    static func usableTextWidth(for textView: NSTextView) -> CGFloat {
        let width = textView.enclosingScrollView?.contentSize.width ?? textView.bounds.width
        return max(260, width - 80)
    }

    static func resizeImage(_ image: NSImage, maxWidth: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxWidth, size.width > 0 else { return image }
        let scale = maxWidth / size.width
        let target = NSSize(width: maxWidth, height: max(1, size.height * scale))
        let resized = NSImage(size: target)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1)
        resized.unlockFocus()
        return resized
    }

    static func toPNGData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    static func markdownTextForSave(from textView: NSTextView) -> String {
        guard let storage = textView.textStorage else { return textView.string }
        let nsString = storage.string as NSString
        var out = ""
        var index = 0
        while index < storage.length {
            var range = NSRange(location: index, length: 1)
            if storage.attribute(.attachment, at: index, effectiveRange: &range) is NSTextAttachment,
               let path = storage.attribute(.imageMarkdownPath, at: index, effectiveRange: nil) as? String {
                out += "![图片](\(path))"
                index = NSMaxRange(range)
                continue
            }
            out += nsString.substring(with: NSRange(location: index, length: 1))
            index += 1
        }
        return out
    }

    static func restoreImageAttachments(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let plain = storage.string
        let regex = try? NSRegularExpression(pattern: #"!\[[^\]\n]*\]\((images/[^)\n]+)\)"#)
        let full = NSRange(location: 0, length: (plain as NSString).length)
        let matches = regex?.matches(in: plain, range: full) ?? []
        guard !matches.isEmpty else { return }

        storage.beginEditing()
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let pathRange = Range(match.range(at: 1), in: plain) else { continue }
            let path = String(plain[pathRange])
            guard let image = image(for: path) else { continue }

            let cell = NSTextAttachmentCell()
            cell.image = image
            let attachment = NSTextAttachment()
            attachment.attachmentCell = cell
            attachment.bounds = NSRect(origin: .zero, size: image.size)

            let attr = NSMutableAttributedString(attachment: attachment)
            attr.addAttribute(.imageMarkdownPath, value: path, range: NSRange(location: 0, length: attr.length))
            storage.replaceCharacters(in: match.range, with: attr)
        }
        storage.endEditing()
    }

    static func openInPreview(path: String) {
        guard let url = resolvedURL(for: path) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func image(for path: String) -> NSImage? {
        guard let url = resolvedURL(for: path) else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func resolvedURL(for path: String) -> URL? {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        guard path.hasPrefix("images/"),
              let dir = ensureImageDir() else {
            return nil
        }
        let name = String(path.dropFirst("images/".count))
        return dir.appendingPathComponent(name)
    }
}
