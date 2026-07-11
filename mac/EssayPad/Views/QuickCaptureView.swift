import SwiftUI
import AppKit

struct QuickCaptureView: View {
    private let store = NoteStore.shared
    @State private var category: NoteCategory = .idea
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var saving = false
    @State private var copyFlash = false
    @State private var didPrefill = false
    var editingNote: Note? = nil
    var onClose: () -> Void
    var onSaved: ((Note) -> Void)? = nil

    private enum Field: Hashable { case title, content }
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            chips
            titleField
            contentEditor
            bottomHint
            actionBar
        }
        .padding(14)
        .frame(width: 480, height: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if !didPrefill {
                didPrefill = true
                if let n = editingNote {
                    title = n.title
                    content = n.content
                    category = n.categoryEnum
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        focusedField = .content
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        focusedField = .title
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: editingNote == nil ? "bolt.fill" : "pencil.circle.fill")
                .foregroundStyle(.white)
                .padding(6)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
            Text(editingNote == nil ? "快提" : "编辑笔记")
                .font(.headline)
            Spacer()
            Button {
                copyMarkdown()
            } label: {
                Image(systemName: copyFlash ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(copyFlash ? Color.green : .secondary)
                    .padding(5)
                    .background(Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("复制 Markdown")
            .disabled(title.isEmpty && content.isEmpty)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor),
                                in: Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape)
        }
    }

    private var chips: some View {
        HStack(spacing: 4) {
            ForEach(NoteCategory.allCases) { c in
                Button {
                    category = c
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: c.icon)
                        Text(c.name)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category == c ? c.tint : Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(category == c ? .white : .primary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(c.rawValue)")),
                                  modifiers: .command)
            }
            Spacer()
        }
    }

    private var titleField: some View {
        TextField("标题(可选)", text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 6))
            .focused($focusedField, equals: .title)
    }

    private var contentEditor: some View {
        MarkdownStyledEditor(
            text: content,
            focusOnAppear: editingNote != nil,
            fontSize: 13,
            horizontalPadding: 10,
            verticalPadding: 8,
            onTextChange: { newValue in
                if content != newValue { content = newValue }
            }
        )
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .frame(minHeight: 100)
    }

    private var bottomHint: some View {
        HStack(spacing: 6) {
            if saving {
                ProgressView().scaleEffect(0.5)
                Text("保存中…").font(.caption).foregroundColor(.secondary)
            } else {
                Image(systemName: "option")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Space 打开 / Esc 关闭").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text("⌘↩ 保存")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var actionBar: some View {
        HStack {
            if editingNote != nil {
                Button(role: .destructive) {
                    Task { await delete() }
                } label: {
                    Text("删除")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
            }
            Spacer()
            Button {
                Task { await save() }
            } label: {
                Text(editingNote == nil ? "保存" : "覆盖保存")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(title.isEmpty || saving)
        }
    }

    private func copyMarkdown() {
        let md: String
        if let n = editingNote {
            md = n.toMarkdown()
        } else {
            md = title.isEmpty ? content : "# \(title)\n\n\(content)"
        }
        ClipboardHelper.copy(md)
        copyFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            copyFlash = false
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if let n = editingNote {
            if let updated = await store.update(n, title: title, content: content, category: category) {
                onSaved?(updated)
            }
        } else {
            if let created = await store.create(category: category, title: title, content: content) {
                onSaved?(created)
            }
        }
        onClose()
    }

    private func delete() async {
        if let n = editingNote {
            await store.delete(n)
        }
        onClose()
    }
}
