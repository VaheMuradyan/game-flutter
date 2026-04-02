import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_match/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PixelMatchApp());
    await tester.pump();
  });
}
