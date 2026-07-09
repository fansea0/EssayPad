import Foundation
import Observation

@MainActor
@Observable
final class NoteStore {
    static let shared = NoteStore()

    var notesByCategory: [NoteCategory: [Note]] = [:]
    var selectedCategory: NoteCategory = .bug
    var loading = false
    var error: String?

    func load() async {
        loading = true
        defer { loading = false }
        do {
            for cat in NoteCategory.allCases {
                let (_, list) = try await APIClient.shared.listNotes(category: cat)
                notesByCategory[cat] = list
            }
            error = nil
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func reload(_ cat: NoteCategory) async {
        do {
            let (_, list) = try await APIClient.shared.listNotes(category: cat)
            notesByCategory[cat] = list
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    @discardableResult
    func create(category: NoteCategory, title: String, content: String) async -> Note? {
        do {
            let n = try await APIClient.shared.createNote(category: category, title: title, content: content)
            notesByCategory[category, default: []].insert(n, at: 0)
            return n
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func update(_ note: Note, title: String, content: String, category: NoteCategory) async -> Note? {
        NSLog("[ES] store.update CALLED note_id=\(note.id) title='\(title)' content_len=\(content.count) content_first50='\(String(content.prefix(50)))' cat=\(category.rawValue)")
        do {
            let updated = try await APIClient.shared.updateNote(
                id: note.id, title: title, content: content, category: category
            )
            notesByCategory[note.categoryEnum]?.removeAll { $0.id == updated.id }
            notesByCategory[category, default: []].insert(updated, at: 0)
            NSLog("[ES] store.update id=\(updated.id) title=\(updated.title) cats=\(notesByCategory.keys.map { String(describing: $0) }.joined(separator: ","))")
            return updated
        } catch {
            NSLog("[ES] store.update FAIL id=\(note.id): \(error)")
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func delete(_ note: Note) async {
        do {
            try await APIClient.shared.deleteNote(id: note.id)
            notesByCategory[note.categoryEnum]?.removeAll { $0.id == note.id }
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
