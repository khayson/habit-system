import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/main.dart' as app;
import 'package:integration_test/integration_test.dart';

/// Phase 0 gate: the real app on an emulator calls GET /health on the running API and shows
/// server_time. Needs the API reachable at API_BASE_URL (default http://10.0.2.2:8000/api/v1).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app shows server_time from /health', (tester) async {
    await app.main();

    final serverTime = find.byKey(const Key('server-time'));
    for (var i = 0; i < 100 && serverTime.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Connected'), findsOneWidget);
    final text = tester.widget<SelectableText>(serverTime).data!;
    expect(text, matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')));
    final skew = DateTime.parse(text).difference(DateTime.now().toUtc()).abs();
    expect(
      skew,
      lessThan(const Duration(minutes: 5)),
      reason: 'server_time is live, not a fixture',
    );
    debugPrint('PHASE0_GATE server_time=$text');
  });
}
