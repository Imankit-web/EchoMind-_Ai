import 'package:flutter_test/flutter_test.dart';
import 'package:echomind_ai/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App Initialization Smoke Test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'isFirstRun': true});
    await AppSettings().init();

    await tester.pumpWidget(const EchoMindAiApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to EchoMind AI'), findsWidgets);
  });
}
