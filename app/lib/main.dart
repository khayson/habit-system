import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_store.dart';
import 'providers/health_provider.dart';
import 'providers/session_provider.dart';
import 'services/health_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const tokens = SecureTokenStore();
  final api = ApiClient(tokens: tokens);
  final session = SessionProvider(tokens);
  api.onUnauthenticated = session.handleUnauthenticated;
  await session.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(create: (_) => HealthProvider(HealthService(api))),
      ],
      child: HabitApp(router: buildRouter(session)),
    ),
  );
}
