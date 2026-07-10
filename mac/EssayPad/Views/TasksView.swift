import SwiftUI

struct TasksView: View {
    @Binding var tasks: [TodoTask]
    @Binding var selectedGroup: TaskGroup
    @Binding var loading: Bool
    @Binding var detailTask: TodoTask?
    @Binding var confettiAnchor: CGPoint?
    @Binding var error: String?
    let onLoad: () -> Void
    var onNavigateToNote: (Int64) -> Void = { _ in }
    var onStartPomodoro: (TodoTask) -> Void = { _ in }

    @State private var showNewTaskSheet = false
    @State private var newTaskTitle = ""
    @State private var newTaskPriority: Int = 0
    @State private var triggerId = 0

    var body: some View {
        let activeCount = tasks.filter { !$0.isDone }.count
        let doneCount = tasks.filter { $0.isDone }.count
        let secs = prioritySections.map { "p\($0.priority):\($0.tasks.count)" }.joined(separator: " ")
        let _ = NSLog("[ES] TasksView body total=\(tasks.count) active=\(activeCount) done=\(doneCount) sections=[\(secs)] group=\(selectedGroup.rawValue) loading=\(loading)")
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("任务")
                    .font(.title2.bold())
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(statsText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    presentNewTaskSheet()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("新建任务")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            HStack(spacing: 4) {
                ForEach(TaskGroup.allCases) { g in
                    Button {
                        if selectedGroup != g && !loading {
                            NSLog("[ES] TasksView tab button tapped new=\(g.rawValue) old=\(selectedGroup.rawValue)")
                            selectedGroup = g
                        }
                    } label: {
                        Text(g.name)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(
                                selectedGroup == g
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.clear,
                                in: Capsule()
                            )
                            .foregroundStyle(selectedGroup == g ? Color.accentColor : .secondary)
                            .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    if loading && tasks.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in TaskRowSkeleton() }
                    } else if let err = error {
                        VStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding(.top, 40)
                    } else if tasks.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text("暂无任务")
                                .foregroundStyle(.secondary)
                            Button("新建第一个任务") { presentNewTaskSheet() }
                                .buttonStyle(.borderless)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding(.top, 40)
                    } else {
                        ForEach(prioritySections, id: \.priority) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: priorityIcon(section.priority))
                                    Text(priorityLabel(section.priority))
                                    Text("(\(section.tasks.count))")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(priorityTint(section.priority).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(priorityTint(section.priority))

                                ForEach(section.tasks) { t in
                                    taskRow(for: t)
                                }
                            }
                        }

                        let doneTasks = tasks.filter { $0.isDone }
                        if !doneTasks.isEmpty {
                            Divider().padding(.vertical, 8)
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("已完成 (\(doneTasks.count))")
                                Spacer()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.green)
                            ForEach(doneTasks) { t in
                                doneTaskRow(for: t)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showNewTaskSheet) {
            NewTaskSheet(
                title: $newTaskTitle,
                priority: $newTaskPriority,
                onCreate: { create() }
            )
        }
        .sheet(item: $detailTask) { t in
            TaskDetailView(task: t, tasks: $tasks, onClose: {
                detailTask = nil
            }, onNavigateToNote: onNavigateToNote)
        }
        .overlay(
            Group {
                if let anchor = confettiAnchor {
                    ConfettiView(origin: anchor)
                        .id(triggerId)
                        .transition(.opacity)
                }
            }
        )
    }

    private var statsText: String {
        let total = tasks.count
        let done = tasks.filter { $0.isDone }.count
        return "\(selectedGroup.name) \(done)/\(total) 完成"
    }

    private func create() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let priority = newTaskPriority
        NSLog("[ES] TasksView.create: title=%@ priority=%d", title, priority)
        Task {
            do {
                _ = try await APIClient.shared.createTask(title: title, priority: priority)
                newTaskTitle = ""
                newTaskPriority = 0
                showNewTaskSheet = false
                NSLog("[ES] TasksView: task created, calling onLoad() to reload group %@", selectedGroup.name)
                onLoad()
            } catch {
                NSLog("[ES] TasksView.create error: %@", String(describing: error))
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func presentNewTaskSheet() {
        newTaskTitle = ""
        newTaskPriority = selectedGroup == .longTerm ? TaskPriority.important.rawValue : TaskPriority.normal.rawValue
        showNewTaskSheet = true
    }

    private func updateProgress(_ id: Int64, to p: Int) async {
        do {
            let updated = try await APIClient.shared.updateTaskProgress(id: id, progress: p)
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx] = updated
            }
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func complete(_ id: Int64) async {
        do {
            let updated = try await APIClient.shared.completeTask(id: id)
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                withAnimation(.easeOut(duration: 0.5)) {
                    tasks[idx] = updated
                }
            }
            SoundPlayer.playTaskComplete()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func taskRow(for t: TodoTask) -> some View {
        TaskRow(
            task: t,
            onTap: { detailTask = t },
            onProgress: { newProgress in
                Task { await updateProgress(t.id, to: newProgress) }
            },
            onComplete: {
                Task { await complete(t.id) }
            },
            onMoveToToday: {
                Task { await moveToToday(t.id) }
            },
            onDelete: {
                Task { await delete(t.id) }
            },
            onChangePriority: { newPriority in
                Task { await changePriority(t.id, to: newPriority) }
            },
            onShowConfetti: { triggerConfetti() },
            onStartPomodoro: { onStartPomodoro(t) }
        )
    }

    private func doneTaskRow(for t: TodoTask) -> some View {
        TaskRow(
            task: t,
            onTap: { detailTask = t },
            onProgress: { _ in },
            onComplete: {},
            onMoveToToday: {},
            onDelete: {
                Task { await delete(t.id) }
            },
            onChangePriority: { _ in },
            onShowConfetti: {},
            onStartPomodoro: {}
        )
    }

    private var activeTasks: [TodoTask] { tasks.filter { !$0.isDone } }

    private var prioritySections: [(priority: Int, tasks: [TodoTask])] {
        [2, 1, 0].compactMap { p in
            let list = activeTasks.filter { $0.priority == p }
            return list.isEmpty ? nil : (p, list)
        }
    }

    private func priorityIcon(_ p: Int) -> String {
        switch p {
        case 2: return "flame.fill"
        case 1: return "star.fill"
        default: return "circle"
        }
    }
    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 2: return "🔥 紧急"
        case 1: return "⭐ 重要"
        default: return "普通"
        }
    }
    private func priorityTint(_ p: Int) -> Color {
        switch p {
        case 2: return .red
        case 1: return .orange
        default: return .gray
        }
    }

    private func moveToToday(_ id: Int64) async {
        do {
            _ = try await APIClient.shared.moveTaskToToday(id: id)
            onLoad()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func changePriority(_ id: Int64, to p: Int) async {
        do {
            let updated = try await APIClient.shared.updateTask(id: id, priority: p)
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx] = updated
            }
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func delete(_ id: Int64) async {
        do {
            try await APIClient.shared.deleteTask(id: id)
            withAnimation {
                tasks.removeAll { $0.id == id }
            }
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func triggerConfetti() {
        let anchor = CGPoint(x: 420, y: 220)
        triggerId += 1
        confettiAnchor = anchor
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.3)) {
                confettiAnchor = nil
            }
        }
    }
}

private struct TaskRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 14)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.1))
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .opacity(0.6)
    }
}

private struct NewTaskSheet: View {
    @Binding var title: String
    @Binding var priority: Int
    let onCreate: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("新建任务")
                .font(.headline)
            TextField("任务标题", text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onCreate() }
            HStack(spacing: 6) {
                Text("优先级")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                ForEach([0, 1, 2], id: \.self) { p in
                    Button {
                        priority = p
                    } label: {
                        Text(priorityLabel(p))
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                priority == p ? priorityTint(p) : Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .foregroundStyle(priority == p ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("创建") { onCreate() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func priorityLabel(_ p: Int) -> String {
        switch p {
        case 0: return "普通"
        case 1: return "⭐ 重要"
        case 2: return "🔥 紧急"
        default: return ""
        }
    }
    private func priorityTint(_ p: Int) -> Color {
        switch p {
        case 2: return Color.red
        case 1: return Color.orange
        default: return Color.gray.opacity(0.6)
        }
    }
}
