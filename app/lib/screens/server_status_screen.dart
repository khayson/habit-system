import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/habit_tokens.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/health_provider.dart';

/// Phase 0 connection check: calls GET /health and shows the server's time.
class ServerStatusScreen extends StatefulWidget {
  const ServerStatusScreen({super.key});

  @override
  State<ServerStatusScreen> createState() => _ServerStatusScreenState();
}

class _ServerStatusScreenState extends State<ServerStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HealthProvider>().check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            Text(l10n.statusTitle, style: text.headlineMedium),
            const SizedBox(height: HabitSpace.s8),
            Text(l10n.statusSubtitle, style: text.bodyLarge?.copyWith(color: tokens.muted)),
            const SizedBox(height: HabitSpace.s24),
            Consumer<HealthProvider>(builder: (context, health, _) => _StatusCard(health: health)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final HealthProvider health;

  const _StatusCard({required this.health});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final status = health.status;
    final error = health.error;

    final Widget body;
    // Any check in flight shows "checking", never the previous answer as if it were current.
    if (health.isLoading) {
      body = Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: HabitSize.icon,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: HabitSpace.s12),
            Expanded(child: Text(l10n.statusChecking, style: text.bodyLarge)),
          ],
        ),
      );
    } else if (error != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(
            icon: Icons.cloud_off_outlined,
            label: l10n.statusOffline,
            background: tokens.warningBg,
            foreground: tokens.warningInk,
          ),
          const SizedBox(height: HabitSpace.s12),
          Text(error.message, style: text.bodyLarge),
          const SizedBox(height: HabitSpace.s8),
          Text(l10n.statusOfflineHint, style: text.bodySmall?.copyWith(color: tokens.muted)),
        ],
      );
    } else if (status != null) {
      final local = DateFormat.yMMMd().add_jms().format(status.serverTime.toLocal());
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(
            icon: Icons.check_circle_outline,
            label: l10n.statusOnline,
            background: tokens.positiveBg,
            foreground: tokens.positiveInk,
          ),
          const SizedBox(height: HabitSpace.s16),
          _Field(
            label: l10n.statusServerTime,
            value: _isoUtc(status.serverTime),
            valueKey: const Key('server-time'),
          ),
          _Field(label: l10n.statusServerTimeLocal, value: local),
          _Field(label: l10n.statusRequestId, value: status.requestId),
        ],
      );
    } else {
      body = const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HabitSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            body,
            const SizedBox(height: HabitSpace.s16),
            OutlinedButton.icon(
              onPressed: health.isLoading ? null : health.check,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.statusCheckAgain),
            ),
          ],
        ),
      ),
    );
  }

  static String _isoUtc(DateTime t) => '${t.toUtc().toIso8601String().split('.').first}Z';
}

/// Status always carries an icon and a word, never colour alone.
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _Badge({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: HabitSpace.s12, vertical: HabitSpace.s4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(HabitRadius.r24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: HabitSpace.s8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final Key? valueKey;

  const _Field({required this.label, required this.value, this.valueKey});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: HabitSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall?.copyWith(color: HabitTokens.of(context).muted)),
          SelectableText(value, key: valueKey, style: text.bodyLarge),
        ],
      ),
    );
  }
}
