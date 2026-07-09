import SwiftUI

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let groups: [(String, [(String, String)])] = [
        ("全局", [
            ("⌥ Space", "随时呼出快提窗"),
            ("⌘ /", "显示本面板"),
        ]),
        ("快提窗", [
            ("⌘ 1 / 2 / 3", "选择分类(bug / 需求 / 想法)"),
            ("⌘ ↩", "保存"),
            ("ESC", "取消"),
        ]),
        ("主窗口", [
            ("⌘ N", "新建笔记"),
            ("⌘ F", "聚焦搜索框"),
            ("⌘ ⇧ A", "切换 AI 周报页"),
            ("⌘ + Click", "多选笔记"),
            ("Delete", "删除选中(多选模式)"),
        ]),
        ("Markdown 编辑", [
            ("⌘ B", "加粗 **"),
            ("⌘ I", "斜体 *"),
            ("⌘ K", "链接 [](url)"),
            ("⌘ ⇧ K", "行内代码 `"),
            ("⌘ ⇧ H", "二级标题 ##"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("快捷键").font(.title3.bold())
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.escape)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(groups, id: \.0) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(g.0)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(g.1.enumerated()), id: \.offset) { _, kv in
                                HStack(alignment: .center) {
                                    Text(kv.0)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Color(nsColor: .controlBackgroundColor),
                                                    in: RoundedRectangle(cornerRadius: 4))
                                    Text(kv.1)
                                        .font(.system(size: 11))
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(width: 400, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}