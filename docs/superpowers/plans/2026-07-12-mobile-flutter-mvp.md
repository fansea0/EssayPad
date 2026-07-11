# Mobile Flutter MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an offline-first Flutter mobile MVP for EssayPad with a compact home screen and basic Markdown note editing.

**Architecture:** `mobile/lib` keeps presentation and the local `NotesStore` separate. UI reads notes only through the store; the first implementation uses `shared_preferences` and can later be replaced with SQLite and a sync-aware repository.

**Tech Stack:** Flutter, Dart, shared_preferences, flutter_markdown.

---

### Task 1: Scaffold and dependencies

**Files:**
- Create: `mobile/pubspec.yaml`
- Create: `mobile/lib/main.dart`
- Modify: `.gitignore`

- [ ] Create the Flutter application with package name `essaypad_mobile`.
- [ ] Add `shared_preferences` and `flutter_markdown`.
- [ ] Run `flutter pub get` and `flutter analyze`.

### Task 2: Local note persistence

**Files:**
- Create: `mobile/lib/features/notes/data/*`
- Create: `mobile/lib/features/notes/domain/note.dart`
- Create: `mobile/test/features/notes/notes_repository_test.dart`

- [ ] Write a failing test for create, update, list, and delete behavior.
- [ ] Implement JSON serialization and the local note store.
- [ ] Run the note model test.

### Task 3: Compact mobile UI

**Files:**
- Create: `mobile/lib/features/home/*`
- Create: `mobile/lib/features/notes/presentation/*`
- Create: `mobile/test/features/home/home_page_test.dart`

- [ ] Write a failing widget test asserting adjacent notes and diary entrances.
- [ ] Implement home, bottom navigation, notes list, note editor, and Markdown shortcuts.
- [ ] Run `flutter test` and `flutter analyze`.

### Task 4: Device verification

**Files:**
- Modify: `mobile/README.md`

- [ ] Run the app on an available simulator or macOS target.
- [ ] Document startup commands and the local-first data behavior.
- [ ] Commit the complete mobile MVP.
