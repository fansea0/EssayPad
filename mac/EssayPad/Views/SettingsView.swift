import SwiftUI
import Observation

@MainActor
@Observable
final class AIConfigurationStore {
    static let shared = AIConfigurationStore()

    var baseURL = ""
    var model = ""
    var hasAPIKey = false
    var error: String?
    private var loaded = false

    func loadIfNeeded() async {
        guard !loaded else { return }
        await reload()
    }

    func reload() async {
        do {
            var current = try await APIClient.shared.fetchAIConfig()
            let defaults = UserDefaults.standard
            let legacyKey = defaults.string(forKey: "ai.apiKey") ?? ""
            if !current.hasAPIKey && !legacyKey.isEmpty {
                try await APIClient.shared.updateAIConfig(
                    baseURL: defaults.string(forKey: "ai.baseURL") ?? current.baseURL,
                    apiKey: legacyKey,
                    model: defaults.string(forKey: "ai.model") ?? current.model
                )
                current = try await APIClient.shared.fetchAIConfig()
            }
            if current.hasAPIKey {
                defaults.removeObject(forKey: "ai.baseURL")
                defaults.removeObject(forKey: "ai.apiKey")
                defaults.removeObject(forKey: "ai.model")
            }
            baseURL = current.baseURL
            model = current.model
            hasAPIKey = current.hasAPIKey
            loaded = true
            error = nil
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func update(apiKey: String?) async throws {
        try await APIClient.shared.updateAIConfig(baseURL: baseURL, apiKey: apiKey, model: model)
        loaded = false
        await reload()
        if let error { throw APIError.decode(error) }
    }
}

struct SettingsView: View {
    @State private var config = AIConfigurationStore.shared
    @State private var apiKey = ""
    @State private var clearAPIKey = false

    @State private var saveState = ""
    @State private var stats: APIClient.AIStats?
    @State private var loading = false

    var body: some View {
        Form {
            Section("AI 配置") {
                TextField("Base URL", text: $config.baseURL)
                SecureField(config.hasAPIKey ? "API Key 已保存，输入新值可替换" : "API Key", text: $apiKey)
                    .onChange(of: apiKey) { _, value in
                        if !value.isEmpty { clearAPIKey = false }
                    }
                TextField("Model", text: $config.model)
                HStack {
                    Button("保存") {
                        Task { await save() }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(loading)

                    if config.hasAPIKey {
                        Button("移除密钥", role: .destructive) {
                            apiKey = ""
                            clearAPIKey = true
                        }
                        .disabled(loading)
                    }

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
            await config.loadIfNeeded()
            if let error = config.error { saveState = error }
            await loadStats()
        }
    }

    private func save() async {
        loading = true
        defer { loading = false }
        do {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyUpdate: String? = clearAPIKey ? "" : (trimmedKey.isEmpty ? nil : trimmedKey)
            try await config.update(apiKey: keyUpdate)
            apiKey = ""
            clearAPIKey = false
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
