import 'package:essaypad_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'weekly reflection displays report and continues the conversation',
      (tester) async {
    tester.view.physicalSize = const Size(430, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: WeeklyReflectionPage()));

    expect(find.text('本周故事'), findsOneWidget);
    expect(find.text('下周建议'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '我下周想少做一点功能');
    await tester.tap(find.byTooltip('发送'));
    await tester.pumpAndSettle();

    expect(find.text('我下周想少做一点功能'), findsOneWidget);
  });
}
