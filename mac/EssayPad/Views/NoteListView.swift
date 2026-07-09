import SwiftUI
import AppKit

struct NoteListView: View {
    @Environment(NoteStore.self) private var store
    @Binding var selection: Note?
    @Binding var showEditor: Bool
    @Binding var searchText: String
    let tasks: [TodoTask]

    var body: some View {
        let _ = store.notesByCategory.values.reduce(0) { $0 + $1.count }

        VStack(spacing: 0) {
            NoteListCategoryBar(
                showEditor: $showEditor,
                selection: $selection
            )

            NoteListQuickDraft(
                selection: $selection,
                showEditor: $showEditor
            )

            NoteListContentArea(
                selection: $selection,
                showEditor: $showEditor,
                searchText: $searchText,
                tasks: tasks
            )
        }
    }
}

private struct NoteListCategoryBar: View {
    @Environment(NoteStore.self) private var store
    @Binding var showEditor: Bool
    @Binding var selection: Note?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(NoteCategory.allCases) { c in
                CategoryChip(
                    category: c,
                    count: store.notesByCategory[c]?.count ?? 0,
                    isSelected: store.selectedCategory == c,
                    action: {
                        store.selectedCategory = c
                        Task { await store.reload(c) }
                    }
                )
            }

            Spacer()

            Button {
                selection = nil
                showEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help("新建随笔")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

private struct NoteListQuickDraft: View {
    @Environment(NoteStore.self) private var store
    @Binding var selection: Note?
    @Binding var showEditor: Bool

    @State private var quickDraftTitle = ""
    @State private var quickDraftCategory: NoteCategory = .idea
    @State private var quickDraftExpanded = false
    @FocusState private var quickTitleFocused: Bool

    var body: some View {
        if quickDraftExpanded {
            expandedDraft
        } else {
            collapsedTrigger
        }
    }

    private var expandedDraft: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("标题…", text: $quickDraftTitle)
                .textFieldStyle(.plain)
                .focused($quickTitleFocused)
                .onSubmit { commitQuickDraft() }
            HStack(spacing: 4) {
                ForEach(NoteCategory.allCases) { c in
                    Button {
                        quickDraftCategory = c
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: c.icon)
                            Text(c.name)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(quickDraftCategory == c ? c.tint : Color(nsColor: .controlBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(quickDraftCategory == c ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("取消") {
                    cancelQuickDraft()
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape)
                Button("保存") {
                    commitQuickDraft()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(quickDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private var collapsedTrigger: some View {
        Button {
            quickDraftExpanded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                quickTitleFocused = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil")
                Text("记一笔…")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func commitQuickDraft() {
        let t = quickDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            cancelQuickDraft()
            return
        }
        let cat = quickDraftCategory
        Task {
            await NoteStore.shared.create(category: cat, title: t, content: "")
            quickDraftTitle = ""
            quickDraftExpanded = false
            await store.reload(cat)
        }
    }

    private func cancelQuickDraft() {
        quickDraftTitle = ""
        quickDraftExpanded = false
    }
}

private struct NoteListContentArea: View {
    @Environment(NoteStore.self) private var store
    @Binding var selection: Note?
    @Binding var showEditor: Bool
    @Binding var searchText: String
    let tasks: [TodoTask]

    @State private var multiSelectMode = false
    @State private var selectedIds: Set<Int64> = []

    var body: some View {
        let _ = store.notesByCategory.values.reduce(0) { $0 + $1.count }
        let filtered = filteredNotes()

        if multiSelectMode {
            NoteListMultiSelectToolbar(
                filtered: filtered,
                selectedCount: selectedIds.count,
                selectAll: { selectedIds = Set(filtered.map { $0.id }) },
                cancel: {
                    multiSelectMode = false
                    selectedIds = []
                },
                delete: { Task { await batchDelete() } }
            )
        }

        if filtered.isEmpty {
            if store.loading {
                NoteListSkeleton()
            } else {
                EmptyListView(hasFilter: !searchText.isEmpty)
            }
        } else {
            NoteListScroll(
                filtered: filtered,
                tasks: tasks,
                selection: $selection,
                showEditor: $showEditor,
                multiSelectMode: $multiSelectMode,
                selectedIds: $selectedIds
            )
            .onExitCommand {
                if multiSelectMode {
                    multiSelectMode = false
                    selectedIds = []
                }
            }
            .onDeleteCommand {
                if multiSelectMode && !selectedIds.isEmpty {
                    Task { await batchDelete() }
                }
            }
        }
    }

    private func filteredNotes() -> [Note] {
        let raw = store.notesByCategory[store.selectedCategory] ?? []
        guard !searchText.isEmpty else { return raw }
        let kw = searchText.lowercased()
        return raw.filter {
            $0.title.lowercased().contains(kw)
                || $0.content.lowercased().contains(kw)
        }
    }

    private func batchDelete() async {
        let toDelete = selectedIds
        let list = store.notesByCategory[store.selectedCategory] ?? []
        let notesToDelete = list.filter { toDelete.contains($0.id) }
        for n in notesToDelete {
            await store.delete(n)
        }
        selectedIds = []
        multiSelectMode = false
    }
}

private struct NoteListMultiSelectToolbar: View {
    let filtered: [Note]
    let selectedCount: Int
    let selectAll: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("已选 \(selectedCount) 项")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Button("全选", action: selectAll)
                .buttonStyle(.borderless)
            Button("取消", action: cancel)
                .buttonStyle(.borderless)
            Button("删除", role: .destructive, action: delete)
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
                .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
    }
}

private struct NoteListSkeleton: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { _ in
                    NoteRowSkeleton()
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }
}

private struct NoteListScroll: View {
    @Environment(NoteStore.self) private var store
    let filtered: [Note]
    let tasks: [TodoTask]
    @Binding var selection: Note?
    @Binding var showEditor: Bool
    @Binding var multiSelectMode: Bool
    @Binding var selectedIds: Set<Int64>

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(filtered, id: \.id) { n in
                    NoteRow(
                        note: n,
                        linkedTaskTitle: linkedTaskTitle(for: n.taskId),
                        isSelected: selection?.id == n.id,
                        isMultiSelect: multiSelectMode,
                        isChecked: selectedIds.contains(n.id)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if multiSelectMode {
                            toggleSelection(n.id)
                        } else {
                            selection = n
                            showEditor = false
                        }
                    }
                    .simultaneousGesture(
                        TapGesture().modifiers(.command).onEnded {
                            if !multiSelectMode {
                                multiSelectMode = true
                            }
                            toggleSelection(n.id)
                        }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    private func toggleSelection(_ id: Int64) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func linkedTaskTitle(for taskId: Int64) -> String? {
        guard taskId > 0 else { return nil }
        return tasks.first(where: { $0.id == taskId })?.title
    }
}

private struct NoteRow: View {
    let note: Note
    var linkedTaskTitle: String? = nil
    let isSelected: Bool
    var isMultiSelect: Bool = false
    var isChecked: Bool = false

    @State private var hovering = false
    @State private var copyFlash = false

    var body: some View {
        HStack(spacing: 10) {
            if isMultiSelect {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                    .frame(width: 22)
            }
            RoundedRectangle(cornerRadius: 6)
                .fill(note.categoryEnum.tint)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: note.categoryEnum.icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .semibold))
                )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(note.title.isEmpty ? "无标题" : note.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    if let t = linkedTaskTitle {
                        HStack(spacing: 2) {
                            Image(systemName: "scope")
                                .font(.system(size: 9, weight: .semibold))
                            Text(t)
                                .lineLimit(1)
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                        .help("关联任务:\(t)")
                    }
                }
                Text(note.content.prefix(80))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(formatTimestamp(note.updatedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isMultiSelect && hovering {
                Button {
                    ClipboardHelper.copy(note.toMarkdown())
                    flash()
                } label: {
                    Image(systemName: copyFlash ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(copyFlash ? Color.green : .secondary)
                        .frame(width: 22, height: 22)
                        .background(Color(nsColor: .windowBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("复制 Markdown")

                Button {
                    QuickCaptureWindowController.shared.openForEditing(note)
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color(nsColor: .windowBackgroundColor),
                                    in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("在快提窗打开")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isChecked ? Color.accentColor.opacity(0.20)
                                : (isSelected ? Color.accentColor.opacity(0.15)
                                               : Color(nsColor: .controlBackgroundColor)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isChecked ? Color.accentColor : (isSelected ? Color.accentColor : Color.clear),
                        lineWidth: 1)
        )
        .onHover { hovering = $0 }
    }

    private func flash() {
        copyFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            copyFlash = false
        }
    }

    private func formatTimestamp(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInYesterday(date) {
            f.dateFormat = "昨天 HH:mm"
        } else if cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            f.dateFormat = "EEEE"
        } else if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
            f.dateFormat = "MM-dd"
        } else {
            f.dateFormat = "yyyy-MM-dd"
        }
        return f.string(from: date)
    }
}

private struct NoteRowSkeleton: View {
    @State private var phase: Double = 0.3
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.2)).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2)).frame(width: 140, height: 12)
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.15)).frame(width: 200, height: 10)
                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.1)).frame(width: 60, height: 8)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .opacity(phase)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                phase = 0.7
            }
        }
    }
}

private struct CategoryChip: View {
    let category: NoteCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: category.icon)
                    .font(.system(size: 10))
                Text(category.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 0)
                        .background((isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.25)),
                                    in: Capsule())
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .fixedSize()
            .background(
                isSelected ? category.tint : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .foregroundStyle(isSelected ? .white : .primary)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help("切换到 \(category.name)")
    }
}

private struct EmptyListView: View {
    let hasFilter: Bool

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: hasFilter ? "magnifyingglass" : "note.text.badge.plus")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(hasFilter ? "没有匹配的内容" : "还没有内容")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(hasFilter
                 ? "试试调整搜索关键词"
                 : "按 ⌥Space 快速记一笔")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}