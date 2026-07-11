import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(NoteStore.self) private var store
    @State private var selection: Note?
    @State private var showEditor = false
    @State private var newEditorID: String? = nil
    @State private var searchText = ""
    @State private var showWeekly = false
    @State private var serverOnline = true
    @State private var showShortcuts = false
    @State private var mainMode: MainMode = .notes
    @State private var diaryStore = DiaryStore()

    @State private var tasks: [TodoTask] = []
    @State private var todayTaskSummary: [TodoTask] = []
    @State private var taskGroup: TaskGroup = .today
    @State private var tasksLoading = false
    @State private var taskLoadGeneration = 0
    @State private var detailTask: TodoTask?
    @State private var confettiAnchor: CGPoint?
    @State private var tasksError: String?
    @State private var pomodoroSetupTask: TodoTask? = nil
    @State private var pomodoroSetupFree: Bool = false

    enum MainMode { case notes, tasks, diary }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                AppSidebarHeader()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                PrimaryNavigation(current: $mainMode)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                if mainMode == .notes {
                    NoteListView(selection: $selection, showEditor: $showEditor,
                                 searchText: $searchText, tasks: tasks)
                } else if mainMode == .tasks {
                    TaskSidebarView(tasks: taskGroup == .today ? tasks : todayTaskSummary,
                                    isLoading: taskGroup == .today && tasksLoading)
                } else if mainMode == .diary {
                    DiarySidebarView(store: diaryStore)
                }

                Spacer(minLength: 0)

                SidebarFooter(serverOnline: serverOnline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .frame(minWidth: 300)
            .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            VStack(spacing: 0) {
                ZStack {
                    if showWeekly {
                        WeeklyReportView(onClose: { showWeekly = false })
                            .transition(.opacity)
                    } else if mainMode == .tasks {
                        tasksContainer
                    } else if mainMode == .diary {
                        diaryContainer
                    } else {
                        notesContainer
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                StatusBar(totalCount: totalCount(),
                           serverOnline: serverOnline,
                           mainMode: mainMode)
            }
            .sheet(item: $pomodoroSetupTask) { task in
                PomodoroSetupView(task: task) { minutes in
                    pomodoroSetupTask = nil
                    PomodoroWindowController.shared.start(task: task, plannedMinutes: minutes)
                } onCancel: {
                    pomodoroSetupTask = nil
                }
            }
            .sheet(isPresented: $pomodoroSetupFree) {
                PomodoroSetupView(task: nil) { minutes in
                    pomodoroSetupFree = false
                    PomodoroWindowController.shared.start(task: nil, plannedMinutes: minutes)
                } onCancel: {
                    pomodoroSetupFree = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startPomodoroFree)) { _ in
                pomodoroSetupFree = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .startPomodoroCountUp)) { _ in
                PomodoroWindowController.shared.startCountUp(task: nil)
            }
            .onReceive(NotificationCenter.default.publisher(for: .startPomodoroRest)) { _ in
                PomodoroWindowController.shared.startRest(minutes: 5)
            }
        }
        .task {
            await store.load()
            serverOnline = await LocalServerManager.isRunning()
        }
        .onChange(of: showEditor) { _, new in
            newEditorID = "new-\(UUID().uuidString)"
        }
        .onChange(of: mainMode) { _, new in
            NSLog("[ES] ContentView mainMode=\(mainModeName(new))")
            if new == .diary {
                Task {
                    await diaryStore.load()
                    await diaryStore.openToday()
                }
            }
        }
        .onChange(of: store.notesByCategory) { _, _ in
            if let sel = selection {
                let allNotes = store.notesByCategory.values.flatMap { $0 }
                if let updated = allNotes.first(where: { $0.id == sel.id }), updated != sel {
                    NSLog("[ES] ContentView syncing selection id=\(sel.id) old_title=\(sel.title) new_title=\(updated.title)")
                    selection = updated
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showWeekly = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("AI 周报")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 4)
                }
                .help("基于近 7 天的随笔生成 AI 周报")
            }
            ToolbarItemGroup(placement: .navigation) {
                if mainMode == .notes {
                    TextField("搜索…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }
        }
        .frame(minWidth: 880, minHeight: 560)
        .onReceive(NotificationCenter.default.publisher(for: .toggleShortcuts)) { _ in
            showShortcuts.toggle()
        }
        .sheet(isPresented: $showShortcuts) {
            ShortcutsSheet()
        }
    }

    @ViewBuilder
    private var notesContainer: some View {
        if showEditor || selection != nil {
            NoteEditorView(note: showEditor ? nil : selection,
                           showEditor: $showEditor,
                           initialCategory: store.selectedCategory)
                .id(showEditor
                    ? (newEditorID ?? "new-init")
                    : "edit-\(selection?.id ?? 0)")
        } else {
            EmptyDetailView()
        }
    }

    @ViewBuilder
    private var tasksContainer: some View {
        TasksView(
            tasks: $tasks,
            selectedGroup: $taskGroup,
            loading: $tasksLoading,
            detailTask: $detailTask,
            confettiAnchor: $confettiAnchor,
            error: $tasksError,
            onLoad: { Task { await loadTasks(for: taskGroup) } },
            onNavigateToNote: { noteId in
                detailTask = nil
                mainMode = .notes
                Task { await openNote(noteId) }
            },
            onStartPomodoro: { task in
                pomodoroSetupTask = task
            }
        )
        .task(id: taskGroup) {
            await loadTasks(for: taskGroup)
        }
    }

    private var diaryContainer: some View {
        DiaryEditorView(store: diaryStore)
            .id("diary-\(diaryStore.selectedEntry?.id ?? 0)-\(diaryStore.selectedDate)")
    }

    private func loadTasks(for group: TaskGroup) async {
        taskLoadGeneration += 1
        let generation = taskLoadGeneration
        NSLog("[ES] loadTasks START group=\(group.rawValue) generation=\(generation) tasks.count=\(tasks.count)")
        tasksLoading = true
        defer {
            if taskLoadGeneration == generation {
                tasksLoading = false
                NSLog("[ES] loadTasks END group=\(group.rawValue) generation=\(generation) tasks.count=\(tasks.count)")
            }
        }
        do {
            let result = try await APIClient.shared.listTasks(group: group)
            // A cancelled or outdated request must not replace the visible task list.
            guard !Task.isCancelled,
                  taskLoadGeneration == generation,
                  TaskLoadPolicy.shouldApply(
                      requestedGroup: group,
                      selectedGroup: taskGroup,
                      isTasksMode: mainMode == .tasks
                  ) else {
                return
            }
            let titles = result.map { "id=\($0.id) title='\($0.title)' priority=\($0.priority) status=\($0.status)" }.joined(separator: " | ")
            NSLog("[ES] loadTasks GOT \(result.count) tasks: [\(titles)]")
            tasks = result
            if group == .today {
                todayTaskSummary = result
            }
            tasksError = nil
        } catch is CancellationError {
            return
        } catch {
            guard taskLoadGeneration == generation,
                  TaskLoadPolicy.shouldApply(
                      requestedGroup: group,
                      selectedGroup: taskGroup,
                      isTasksMode: mainMode == .tasks
                  ) else {
                return
            }
            NSLog("[ES] loadTasks FAIL group=\(group.rawValue): \(error)")
            tasksError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func totalCount() -> Int {
        store.notesByCategory.values.reduce(0) { $0 + $1.count }
    }

    private func mainModeName(_ mode: MainMode) -> String {
        switch mode {
        case .notes:
            return "notes"
        case .tasks:
            return "tasks"
        case .diary:
            return "diary"
        }
    }

    private func openNote(_ id: Int64) async {
        do {
            let note = try await APIClient.shared.getNote(id: id)
            if let cat = NoteCategory(rawValue: note.category) {
                store.selectedCategory = cat
            }
            selection = note
            showEditor = false
        } catch {
            tasksError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct AppSidebarHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text("EssayPad")
                    .font(.system(size: 17, weight: .bold))
                Text("个人工作台")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PrimaryNavigation: View {
    @Binding var current: ContentView.MainMode

    var body: some View {
        VStack(spacing: 3) {
            navigationItem(.notes, icon: "note.text", title: "笔记", subtitle: "随手记录")
            navigationItem(.tasks, icon: "checklist", title: "任务", subtitle: "今日安排")
            navigationItem(.diary, icon: "book.closed", title: "日记", subtitle: "每日回顾")
        }
    }

    private func navigationItem(_ mode: ContentView.MainMode, icon: String, title: String, subtitle: String) -> some View {
        Button {
            current = mode
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(current == mode ? Color.accentColor : Color.secondary)
                    .background(current == mode ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if current == mode {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 40)
            .background(current == mode ? Color.accentColor.opacity(0.10) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("切换到\(title)")
    }
}

private struct SidebarFooter: View {
    let serverOnline: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(serverOnline ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            Text(serverOnline ? "本地数据已连接" : "本地服务未连接")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("设置")
        }
    }
}

private struct TaskSidebarView: View {
    let tasks: [TodoTask]
    let isLoading: Bool

    private var completedCount: Int { tasks.filter(\.isDone).count }
    private var activeTasks: [TodoTask] { tasks.filter { $0.status == 0 } }
    private var focusMinutes: Int { tasks.reduce(0) { $0 + $1.pomodoroTodayMinutes } }
    private var urgentCount: Int { activeTasks.filter { $0.priority == TaskPriority.urgent.rawValue }.count }
    private var importantCount: Int { activeTasks.filter { $0.priority == TaskPriority.important.rawValue }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarTitle("任务", icon: "checklist")

            if isLoading && tasks.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 12)
            } else {
                summaryRow("今天", value: "\(completedCount) / \(tasks.count) 完成", icon: "checkmark.circle")
                summaryRow("专注", value: "\(focusMinutes) 分钟", icon: "timer")
            }

            Divider().padding(.vertical, 14)

            sidebarTitle("优先级", icon: "flag")
            summaryRow("紧急", value: "\(urgentCount)", icon: "exclamationmark.triangle", tint: .red)
            summaryRow("重要", value: "\(importantCount)", icon: "flag.fill", tint: .orange)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func sidebarTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.bottom, 8)
    }

    private func summaryRow(_ title: String, value: String, icon: String, tint: Color = .secondary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .frame(minHeight: 28)
    }
}

private struct StatusBar: View {
    let totalCount: Int
    let serverOnline: Bool
    let mainMode: ContentView.MainMode

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(serverOnline ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                )
            Text(serverOnline ? "后端在线" : "后端离线")
                .font(.caption)
                .foregroundColor(.secondary)
            Divider().frame(height: 12)
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("⌥Space 快速记一笔")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var statusText: String {
        switch mainMode {
        case .notes:
            return "总笔记 \(totalCount) 条"
        case .tasks:
            return "任务面板"
        case .diary:
            return "日记"
        }
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text("还没有内容")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("按 ⌥Space 快速记一笔,或点列表 + 新建")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
