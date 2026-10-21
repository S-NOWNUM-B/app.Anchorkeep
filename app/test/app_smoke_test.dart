import 'package:anchorkeep/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('приложение запускается', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AnchorkeepApp()));
    expect(find.text('Anchorkeep'), findsOneWidget);
  });
}
