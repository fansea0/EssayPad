import 'package:essaypad_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('task progress and focus minutes are persisted in the local task state',
      () async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final store = TaskStore(persistent: false, seed: [
      MobileTask(
        id: 'task-1',
        title: '完成移动端任务页',
        description: '补齐列表、详情和专注。',
        progress: 25,
        priority: TaskPriority.important,
        status: TaskStatus.active,
        dueAt: now,
        createdAt: now,
        updatedAt: now,
        focusMinutes: 10,
      ),
    ]);

    await store.updateProgress('task-1', 100);
    await store.addFocusMinutes('task-1', 25);

    final task = store.tasks.single;
    expect(task.progress, 100);
    expect(task.status, TaskStatus.done);
    expect(task.focusMinutes, 35);
  });
}
