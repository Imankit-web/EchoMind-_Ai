import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_patient_app/main.dart';

void main() {
  testWidgets('Doctor Input Screen Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DoctorPatientApp());

    // Verify that our app bar text is correct.
    expect(find.text('Echo Ai 2.0'), findsOneWidget);

    // Verify that the generate options button exists.
    expect(find.text('Generate Options'), findsOneWidget);
  });
}
