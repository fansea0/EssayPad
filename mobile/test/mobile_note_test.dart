import 'package:essaypad_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note keeps markdown content through json serialization', () {
    final note = MobileNote(
      id: 'note-1',
      title: '产品想法',
      content: '# 标题\n\n**重点**',
      category: NoteCategory.idea,
      updatedAt: DateTime(2026, 7, 12),
    );

    final restored = MobileNote.fromJson(note.toJson());

    expect(restored.content, note.content);
    expect(restored.category, NoteCategory.idea);
  });
}
