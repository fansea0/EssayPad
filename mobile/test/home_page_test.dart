import 'package:essaypad_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home shows adjacent note and diary entrances', (tester) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(EssayPadMobile(
      store: NotesStore(seed: const []),
      diaryStore: DiaryStore(seed: const []),
    ));

    expect(find.text('笔记'), findsOneWidget);
    expect(find.text('日记'), findsAtLeastNWidgets(1));
    expect(find.text('AI 周报'), findsOneWidget);
  });
}
