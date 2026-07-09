import Foundation

enum LocalServerManager {
    static func isRunning() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:18888/health") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
