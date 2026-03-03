import 'package:flutter_test/flutter_test.dart';
import 'package:pdftoolkit/main.dart';
import 'package:pdftoolkit/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('App launches and shows dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Workspace'), findsOneWidget);
  });
}
