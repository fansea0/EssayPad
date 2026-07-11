import 'package:essaypad_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home shows adjacent note and diary entrances', (tester) async {
    await tester.pumpWidget(EssayPadMobile(store: NotesStore(seed: const [])));

    expect(find.text('笔记'), findsOneWidget);
    expect(find.text('日记'), findsOneWidget);
    expect(find.text('最近笔记'), findsOneWidget);
  });
}
