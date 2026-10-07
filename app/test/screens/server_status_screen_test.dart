import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/config/theme.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/l10n/generated/app_localizations.dart';
import 'package:habit/models/health_status.dart';
import 'package:habit/providers/health_provider.dart';
import 'package:habit/screens/server_status_screen.dart';
import 'package:habit/services/health_service.dart';
import 'package:provider/provider.dart';

class FakeHealthService implements HealthService {
  Future<HealthStatus> Function() next;
  FakeHealthService(this.next);

  @override
  Future<HealthStatus> check() => next();
}

Widget harness(HealthService service, {double textScale = 1, ThemeData? theme}) {
  return ChangeNotifierProvider(
    create: (_) => HealthProvider(service),
    child: MaterialApp(
      theme: theme ?? AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const ServerStatusScreen(),
    ),
  );
}

final okStatus = HealthStatus(
  status: 'ok',
  serverTime: DateTime.utc(2026, 5, 28, 17, 22),
  requestId: '0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f',
);

void main() {
  testWidgets('shows server_time after a successful check', (tester) async {
    await tester.pumpWidget(harness(FakeHealthService(() async => okStatus)));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
    expect(
      find.byIcon(Icons.check_circle_outline),
      findsOneWidget,
      reason: 'status is not colour alone',
    );
    expect(find.text('2026-05-28T17:22:00Z'), findsOneWidget);
    expect(find.text(okStatus.requestId), findsOneWidget);
  });

  testWidgets('shows a loading state while checking', (tester) async {
    final pending = Completer<HealthStatus>();
    await tester.pumpWidget(harness(FakeHealthService(() => pending.future)));
    await tester.pump();

    expect(find.text('Checking the connection…'), findsOneWidget);
    pending.complete(okStatus);
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error with retry, then recovers', (tester) async {
    var fail = true;
    final service = FakeHealthService(() async {
      if (fail) {
        throw const AppException(
          kind: AppErrorKind.network,
          code: 'network_unavailable',
          message: 'Could not reach the server. Your work stays on this device.',
        );
      }
      return okStatus;
    });
    await tester.pumpWidget(harness(service));
    await tester.pumpAndSettle();

    expect(find.text('Not connected'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('retry button is at least 44 px tall', (tester) async {
    await tester.pumpWidget(harness(FakeHealthService(() async => okStatus)));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(OutlinedButton)).height, greaterThanOrEqualTo(44));
  });

  testWidgets('survives 200% text scale and dark theme without overflow', (tester) async {
    await tester.pumpWidget(
      harness(FakeHealthService(() async => okStatus), textScale: 2, theme: AppTheme.dark),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Connected'), findsOneWidget);
  });
}
