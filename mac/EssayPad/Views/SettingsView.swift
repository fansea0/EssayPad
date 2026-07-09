import SwiftUI

struct SettingsView: View {
    @AppStorage("ai.baseURL") private var baseURL = "https://api.openai.com/v1"
    @AppStorage("ai.apiKey") private var apiKey = ""
    @AppStorage("ai.model") private var model = "gpt-4o-mini"

    @State private var saveState = ""
    @State private var stats: APIClient.AIStats?
    @State private var loading = false

    var body: some View {
        Form {
            Section("AI 配置") {
                TextField("Base URL", text: $baseURL)
                SecureField("API Key", text: $apiKey)
                TextField("Model", text: $model)
                HStack {
                    Button("保存") {
                        Task { await save() }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(loading)

                    if loading {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text(saveState)
                        .foregroundStyle(saveState == "已保存" ? Color.secondary : Color.red)
                }
            }

            Section("调用统计") {
                LabeledContent("总调用", value: "\(stats?.totalCalls ?? 0)")
                LabeledContent("成功", value: "\(stats?.success ?? 0)")
                LabeledContent("失败", value: "\(stats?.failed ?? 0)")
                LabeledContent("Token", value: "\(stats?.totalTokens ?? 0)")
                if let err = stats?.lastError, !err.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("刷新统计") {
                    Task { await loadStats() }
                }
                .disabled(loading)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 360)
        .task {
            await loadStats()
        }
    }

    private func save() async {
        loading = true
        defer { loading = false }
        do {
            try await APIClient.shared.updateAIConfig(baseURL: baseURL, apiKey: apiKey, model: model)
            saveState = "已保存"
            await loadStats()
        } catch {
            saveState = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadStats() async {
        loading = true
        defer { loading = false }
        do {
            stats = try await APIClient.shared.fetchAIStats()
        } catch {
            saveState = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
