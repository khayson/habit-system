import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'config/api_config.dart';
import 'config/legal_config.dart';
import 'core/network/api_client.dart';
import 'core/storage/account_store.dart';
import 'core/storage/token_store.dart';
import 'core/time_zones.dart';
import 'providers/account_context.dart';
import 'providers/health_provider.dart';
import 'providers/session_provider.dart';
import 'services/auth_service.dart';
import 'services/health_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.ensureSafe();
  LegalConfig.ensureSafe();
  LicenseRegistry.addLicense(_interLicense);

  const tokens = SecureTokenStore();
  final api = ApiClient(tokens: tokens);
  final auth = AuthService(api, tokens, const SecureAccountStore());
  final session = SessionProvider(
    auth,
    buildAccount: (account) => AccountContext.live(account, api, auth),
  );
  api.onUnauthenticated = session.handleUnauthenticated;
  // Reads the keystore and opens the account database lazily: no network, no artificial delay.
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

  // After the first frame: the tz database, then the start-up sync (foreground only).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    TimeZones.load();
    session.account?.sync.onForeground();
  });
  session.addListener(() {
    // A fresh sign-in starts its first sync at once.
    final account = session.account;
    if (account != null && account.sync.lastOutcome == null && !account.sync.syncing) {
      account.sync.onForeground();
    }
  });
}

/// Inter is bundled under the SIL Open Font License; its notice ships with the app.
Stream<LicenseEntry> _interLicense() async* {
  final text = await rootBundle.loadString('assets/fonts/inter/LICENSE.txt');
  yield LicenseEntryWithLineBreaks(const ['Inter'], text);
}
