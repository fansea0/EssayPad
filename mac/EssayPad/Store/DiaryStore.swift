import Foundation
import Observation

@MainActor
@Observable
final class DiaryStore {
    var entries: [DiaryEntry] = []
    var selectedEntry: DiaryEntry?
    var selectedDate: Int64 = DiaryStore.todayStart()
    var listMode: DiaryListMode = .all
    var searchText = ""
    var loading = false
    var error: String?

    func load() async {
        loading = true
        defer { loading = false }
        do {
            let (_, list) = try await APIClient.shared.listDiaries(mode: listMode, keyword: searchText)
            entries = list
            error = nil
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func openToday() async {
        selectedDate = Self.todayStart()
        await openDate(selectedDate)
    }

    func openDate(_ date: Int64) async {
        selectedDate = date
        do {
            selectedEntry = try await APIClient.shared.getDiaryByDate(date: date)
            error = nil
        } catch let apiError as APIError {
            if case .http(let status, _) = apiError, status == 404 {
                selectedEntry = nil
                error = nil
            } else {
                selectedEntry = nil
                error = apiError.errorDescription
            }
        } catch {
            selectedEntry = nil
            self.error = error.localizedDescription
        }
    }

    @discardableResult
    func save(date: Int64, title: String, content: String, mood: Int, status: Int, activity: Int) async -> DiaryEntry? {
        do {
            let entry = try await APIClient.shared.saveDiary(
                date: date,
                title: title,
                content: content,
                mood: mood,
                status: status,
                activity: activity
            )
            selectedDate = entry.diaryDate
            selectedEntry = entry
            upsert(entry)
            error = nil
            return entry
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func update(_ entry: DiaryEntry, title: String, content: String, mood: Int, status: Int, activity: Int) async -> DiaryEntry? {
        do {
            let updated = try await APIClient.shared.updateDiary(
                id: entry.id,
                title: title,
                content: content,
                mood: mood,
                status: status,
                activity: activity
            )
            selectedEntry = updated
            upsert(updated)
            error = nil
            return updated
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func deleteSelected() async {
        guard let entry = selectedEntry else { return }
        do {
            try await APIClient.shared.deleteDiary(id: entry.id)
            entries.removeAll { $0.id == entry.id }
            selectedEntry = nil
            error = nil
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func upsert(_ entry: DiaryEntry) {
        entries.removeAll { $0.id == entry.id || $0.diaryDate == entry.diaryDate }
        entries.append(entry)
        entries.sort {
            if $0.diaryDate != $1.diaryDate { return $0.diaryDate > $1.diaryDate }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id > $1.id
        }
    }

    static func todayStart() -> Int64 {
        let start = Calendar.current.startOfDay(for: Date())
        return Int64(start.timeIntervalSince1970)
    }

    static func dateStart(_ date: Date) -> Int64 {
        Int64(Calendar.current.startOfDay(for: date).timeIntervalSince1970)
    }
}
