import SwiftUI
import AppKit

private enum SaveState: Equatable {
    case idle
    case saving
    case saved
    case error(String)
}

struct NoteEditorView: View {
    @Environment(NoteStore.self) private var store
    @Binding var showEditor: Bool
    @State private var title: String
    @State private var content: String
    @State private var category: NoteCategory
    @State private var savedNote: Note?
    @State private var saveState: SaveState = .idle
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var hasInitiallySaved = false
    @State private var hoveringToolbar = false
    let note: Note?
    let initialCategory: NoteCategory

    init(note: Note?, showEditor: Binding<Bool>, initialCategory: NoteCategory) {
        self.note = note
        self._showEditor = showEditor
        self.initialCategory = initialCategory
        _title = State(initialValue: note?.title ?? "")
        _content = State(initialValue: note?.content ?? "")
        _category = State(initialValue: note.map {
            NoteCategory(rawValue: $0.category) ?? initialCategory
        } ?? initialCategory)
        _savedNote = State(initialValue: note)
        _hasInitiallySaved = State(initialValue: note != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
                .padding(.horizontal, 32)
            titleField
            Divider()
                .padding(.horizontal, 32)
                .padding(.bottom, 8)
            editorArea
            Spacer(minLength: 0)
            Divider()
                .padding(.horizontal, 32)
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: content) { _, _ in
            NSLog("[ES] onChange(of: content) content_len=\(content.count)")
            scheduleAutoSave()
        }
        .onChange(of: title) { _, _ in
            NSLog("[ES] onChange(of: title) title_len=\(title.count)")
            scheduleAutoSave()
        }
        .onDisappear {
            autoSaveTask?.cancel()
            autoSaveTask = nil
            Task { await cleanupEmptyDraft() }
        }
        .background(
            Button("") {
                NSLog("[ES] ⌘S action")
                autoSaveTask?.cancel()
                autoSaveTask = Task { await autoSave() }
            }
            .keyboardShortcut("s", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(category.tint)
                    .frame(width: 8, height: 8)
                Text(category.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(note == nil ? "新建随笔" : "在侧栏切换分类")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if hoveringToolbar {
                Button {
                    ClipboardHelper.copy(toMarkdownString())
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("复制 Markdown")

                Menu {
                    if note != nil {
                        Button("删除", role: .destructive) {
                            Task { await delete() }
                        }
                    }
                    Button("复制纯文本") {
                        ClipboardHelper.copy(toPlainTextString())
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            } else {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary.opacity(0.001))
                    .fixedSize()
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        .onHover { hoveringToolbar = $0 }
    }

    private var titleField: some View {
        TextField("标题", text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .padding(.bottom, 12)
    }

    private var editorArea: some View {
        MarkdownStyledEditor(
            text: content,
            onTextChange: { newValue in
                if content != newValue {
                    NSLog("[ES] NoteEditorView onTextChange set content=\(newValue.count)c")
                    content = newValue
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("\(wordCount) 字")
                    .foregroundStyle(.secondary)
                saveStatusView
            }
            .font(.system(size: 11))

            Spacer()

            Text("⌘B/I/K/U  样式  ⌘⇧K 代码  ⌘⇧H 标题")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }

    @ViewBuilder
    private var saveStatusView: some View {
        switch saveState {
        case .idle:
            if let saved = savedNote {
                Text("· \(relativeTime(saved.updatedAt))")
                    .foregroundStyle(.secondary)
            }
        case .saving:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                Text("保存中")
                    .foregroundStyle(.secondary)
            }
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                Text("已保存")
                    .foregroundStyle(.secondary)
            }
            .transition(.opacity)
            .task(id: saveState) {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if saveState == .saved { saveState = .idle }
            }
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .foregroundStyle(.red)
            }
            .help(msg)
        }
    }

    private var wordCount: Int {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        let cjk = content.reduce(0) { acc, c in
            let s = String(c)
            return acc + (s.range(of: "[\\u4e00-\\u9fa5]", options: .regularExpression) != nil ? 1 : 0)
        }
        let nonCjk = content
            .replacingOccurrences(of: "[\\u4e00-\\u9fa5]", with: " ",
                                  options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace })
            .count
        return cjk + nonCjk
    }

    private func relativeTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "zh_CN")
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func toMarkdownString() -> String {
        var out = title.isEmpty ? "" : "# \(title)"
        if !content.isEmpty {
            if !out.isEmpty { out += "\n\n" }
            out += content
        }
        if !out.hasSuffix("\n") { out += "\n" }
        return out
    }

    private func toPlainTextString() -> String {
        return title.isEmpty && content.isEmpty ? "" :
               title.isEmpty ? content :
               content.isEmpty ? title :
               "\(title)\n\n\(content)"
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        let newID = UUID().uuidString.prefix(8)
        NSLog("[ES] scheduleAutoSave id=\(newID) title=\(title.count)c content=\(content.count)c savedNote=\(savedNote?.id ?? -1)")
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else {
                NSLog("[ES] autosave cancelled id=\(newID)")
                return
            }
            await autoSave()
        }
    }

    private func autoSave() async {
        NSLog("[ES] autoSave called savedNote=\(savedNote?.id ?? -1) title=\(title.count)c content=\(content.count)c")
        guard !title.isEmpty || !content.isEmpty else {
            saveState = .idle
            return
        }
        if let saved = savedNote {
            saveState = .saving
            if let updated = await store.update(saved, title: title, content: content, category: category) {
                savedNote = updated
                NSLog("[ES] autoSave updated id=\(updated.id)")
                saveState = .saved
            } else {
                saveState = .error(store.error ?? "保存失败")
            }
            return
        }
        guard !title.isEmpty else {
            saveState = .idle
            return
        }
        saveState = .saving
        if let created = await store.create(category: category, title: title, content: content) {
            savedNote = created
            hasInitiallySaved = true
            saveState = .saved
            NSLog("[ES] autoSave created id=\(created.id)")
        } else {
            let msg = store.error ?? "创建失败"
            NSLog("[ES] autoSave create failed: \(msg)")
            saveState = .error(msg)
        }
    }

    private func cleanupEmptyDraft() async {
        guard let saved = savedNote else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.isEmpty && c.isEmpty else { return }
        await store.delete(saved)
    }

    private func delete() async {
        if let n = savedNote { await store.delete(n) }
        showEditor = false
    }
}
