import 'package:flutter_test/flutter_test.dart';
import 'package:misfir_mobile_admin/main.dart';

void main() {
  testWidgets('Misafir Admin smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MisafirAdminApp());
    expect(find.text('MİSAFİR'), findsOneWidget);
  });
}
