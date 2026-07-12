import 'package:essaypad_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('diary list groups entries and shows diary metadata',
      (tester) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final store = DiaryStore(seed: [
      MobileDiary(
        id: 'diary-1',
        title: '专注创造价值',
        content: '今天把移动端日记列表补起来了。',
        mood: DiaryMood.calm,
        activity: DiaryActivity.work,
        createdAt: now,
      ),
    ]);

    await tester.pumpWidget(EssayPadMobile(
      store: NotesStore(seed: const []),
      diaryStore: store,
      taskStore: TaskStore(seed: const []),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('日记').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();

    expect(find.text('日记'), findsAtLeastNWidgets(1));
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('专注创造价值'), findsOneWidget);
    expect(find.text('平静'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
  });
}
