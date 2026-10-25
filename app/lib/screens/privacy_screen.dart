import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/exceptions/app_exception.dart';
import '../core/file_sharer.dart';
import '../data/account_calendar.dart';
import '../data/local_view.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/export_job.dart';
import '../providers/account_context.dart';
import '../sync/outbox_states.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import '../widgets/app_icons.dart';

/// Words for an export job, from the account calendar (invariant 15).
class ExportWords {
  final AppLocalizations l10n;
  final HabitFormat format;
  final AccountCalendar? calendar;
  final DateTime deviceNow;

  const ExportWords(this.l10n, this.format, this.calendar, this.deviceNow);

  String kind(String f) => f == 'csv' ? l10n.exportKindCsv : l10n.exportKindJson;
  String short(String f) => f == 'csv' ? l10n.exportFormatCsv : l10n.exportFormatJson;

  String status(ExportStatus s) => switch (s) {
    ExportStatus.queued => l10n.exportStatusQueued,
    ExportStatus.running => l10n.exportStatusRunning,
    ExportStatus.ready => l10n.exportStatusReady,
    ExportStatus.failed => l10n.exportStatusFailed,
    ExportStatus.expired => l10n.exportStatusExpired,
    ExportStatus.unknown => l10n.exportStatusUnknown,
  };

  /// "27 May" in the account's calendar.
  String day(DateTime? instant) {
    final c = calendar;
    if (instant == null || c == null) return '';
    return format.dayMonth(c.timeline.localDateAt(instant));
  }

  /// "today at 10:22" or "27 May at 10:22".
  String when(DateTime? instant) {
    final c = calendar;
    if (instant == null || c == null) return '';
    final time = format.time(c.localTimeAt(instant));
    final date = c.timeline.localDateAt(instant);
    return date == c.today(deviceNow)
        ? l10n.exportWhenToday(time)
        : l10n.exportWhenDay(format.dayMonth(date), time);
  }
}

/// The selected format on 21, in memory for the session.
String _privacyFormat = 'json';

/// Tests start each case on JSON.
@visibleForTesting
void resetPrivacyFormatForTest() => _privacyFormat = 'json';

/// Screen 21, "Your data, yours" (A48). Exports are explicit network actions: the latest job
/// comes from GET /exports, nothing is written to the database. Delete account opens 28 (A49).
/// Restore (6.3) is not offered yet: ASSUMPTION(A48-phasing).
class PrivacyScreen extends StatefulWidget {
  final FileSharer sharer;
  final DateTime Function() clock;

  const PrivacyScreen({super.key, required this.sharer, this.clock = DateTime.now});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  String _format = _privacyFormat;
  List<ExportJob>? _jobs;
  bool _loading = false;
  bool _failed = false;
  bool _busy = false;
  String? _actionError;
  AccountCalendar? _calendar;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_jobs == null && !_loading) _load();
  }

  Future<void> _load() async {
    final account = context.read<AccountContext?>();
    if (account == null) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final calendar = await AccountCalendar.load(account.session.db, deviceNow: widget.clock());
    try {
      final api = account.exportsApi ?? (throw const _NoServer());
      final jobs = await api.list();
      if (mounted) setState(() => _jobs = jobs);
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _calendar = calendar;
        });
      }
    }
  }

  ExportJob? get _latest => _jobs?.where((j) => j.format == _format).firstOrNull;

  Future<void> _request() async {
    final account = context.read<AccountContext>();
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final api = account.exportsApi ?? (throw const _NoServer());
      final job = await api.request(_format);
      if (!mounted) return;
      await context.push(Routes.exportStatus(job.id), extra: job);
      if (mounted) _load();
    } on Object {
      if (mounted) setState(() => _actionError = l10n.privacyRequestError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(ExportJob job) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await downloadAndShare(context.read<AccountContext>(), job, widget.sharer);
    } on Object catch (e) {
      final expired = e is AppException && e.code == 'export_expired';
      if (mounted) {
        setState(
          () => _actionError = expired ? l10n.privacyDownloadExpired : l10n.privacyDownloadError,
        );
      }
      // 6.1 review L4: the link's 24 hours are over; the list now reads expired.
      if (expired && mounted) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AccountContext?>();
    if (account == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final words = ExportWords(l10n, HabitFormat(context), _calendar, widget.clock());
    final latest = _latest;
    final muted = text.bodyMedium?.copyWith(color: tokens.muted);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(HabitSpace.margin),
            children: [
              ScreenHeader(
                title: l10n.privacyTitle,
                subtitle: l10n.privacySubtitle,
                onBack: () => context.canPop() ? context.pop() : context.go(Routes.profile),
              ),
              SegmentedTabs(
                labels: [l10n.privacyJson, l10n.privacyCsv],
                selected: _format == 'json' ? 0 : 1,
                onSelected: (i) =>
                    setState(() => _format = _privacyFormat = i == 0 ? 'json' : 'csv'),
              ),
              const SizedBox(height: HabitSpace.s16),
              Semantics(
                container: true,
                label:
                    '${l10n.privacyIncludedTitle}, ${l10n.privacyIncludedBody}, ${l10n.privacyIncludedAll}',
                excludeSemantics: true,
                child: SurfaceCard(
                  child: Row(
                    children: [
                      const IconTile(icon: AppIcons.book),
                      const SizedBox(width: HabitSpace.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.privacyIncludedTitle, style: text.titleMedium),
                            const SizedBox(height: HabitSpace.s4),
                            Text(
                              l10n.privacyIncludedBody,
                              style: text.bodySmall?.copyWith(color: tokens.muted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        l10n.privacyIncludedAll,
                        style: text.bodyMedium?.copyWith(color: tokens.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: HabitSpace.s16),
              ListenableBuilder(
                listenable: account.queue,
                builder: (context, _) {
                  final queue = account.queue.value;
                  final waiting = (queue?.items ?? const <QueueItem>[])
                      .where((i) => OutboxState.unacked.contains(i.row.state))
                      .length;
                  final synced = queue?.state.lastSyncedAt;
                  return waiting > 0
                      ? InfoCard(
                          title: l10n.privacyPendingTitle(waiting),
                          body: l10n.privacyPendingBody,
                          tone: Tone.info,
                        )
                      : InfoCard(
                          title: l10n.privacyUpToDateTitle,
                          body: synced == null
                              ? l10n.privacyNeverSynced
                              : l10n.privacyUpToDateBody(
                                  words.when(
                                    DateTime.fromMillisecondsSinceEpoch(synced, isUtc: true),
                                  ),
                                ),
                        );
                },
              ),
              const SizedBox(height: HabitSpace.s16),
              if (_jobs == null && _loading)
                const Padding(
                  padding: EdgeInsets.all(HabitSpace.s24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_jobs == null && _failed) ...[
                Text(l10n.privacyLoadError, style: muted),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(HabitSize.minTarget, HabitSize.minTarget),
                    ),
                    onPressed: _load,
                    child: Text(l10n.ledgerTryAgain),
                  ),
                ),
              ] else
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest == null
                            ? l10n.privacyLatestNone
                            : l10n.privacyLatest(words.status(latest.status)),
                        style: text.titleMedium,
                      ),
                      if (latest != null) ...[
                        const SizedBox(height: HabitSpace.s8),
                        Text(
                          l10n.privacyRequested(
                            words.short(latest.format),
                            words.day(latest.requestedAt),
                          ),
                          style: muted,
                        ),
                        if (latest.status == ExportStatus.ready) ...[
                          const SizedBox(height: HabitSpace.s12),
                          Text(
                            l10n.privacyExpiresNote,
                            style: text.bodySmall?.copyWith(color: tokens.muted),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              if (_actionError != null) ...[
                const SizedBox(height: HabitSpace.s12),
                Semantics(liveRegion: true, child: Text(_actionError!, style: muted)),
              ],
              const SizedBox(height: HabitSpace.s16),
              if (latest?.status == ExportStatus.ready) ...[
                _TonalButton(
                  label: l10n.privacyDownload,
                  onPressed: _busy ? null : () => _download(latest!),
                ),
                const SizedBox(height: HabitSpace.s12),
              ],
              Center(
                child: TextButton(
                  // As drawn: a quiet text action, smaller than the buttons around it.
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.muted,
                    textStyle: text.bodyMedium,
                  ),
                  onPressed: _busy ? null : () => context.push(Routes.deleteAccount),
                  child: Text(l10n.privacyDeleteAccount),
                ),
              ),
              const SizedBox(height: HabitSpace.s12),
              PrimaryButton(label: l10n.privacyRequest, loading: _busy, onPressed: _request),
              const SizedBox(height: HabitSpace.s16),
              Text(
                l10n.privacyFooter,
                style: text.bodySmall?.copyWith(color: tokens.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoServer implements Exception {
  const _NoServer();
}

/// The design's light green button (21's "Download latest export", 30's second button).
class _TonalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _TonalButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final tokens = HabitTokens.of(context);
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(HabitSize.control),
          backgroundColor: tokens.positiveBg,
          foregroundColor: tokens.positiveInk,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HabitRadius.r16)),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Public for 29: the design's tonal button.
Widget tonalButton({required String label, required VoidCallback? onPressed}) =>
    _TonalButton(label: label, onPressed: onPressed);

/// A48: downloads [job] into a temporary folder, hands it to the share sheet, then deletes it.
Future<void> downloadAndShare(AccountContext account, ExportJob job, FileSharer sharer) async {
  final api =
      account.exportsApi ??
      (throw const AppException(kind: AppErrorKind.network, code: 'network', message: ''));
  final folder = await (await sharer.temporaryRoot()).createTemp('export_');
  try {
    final file = await api.download(job, folder.path);
    await sharer.share(file.path);
  } finally {
    try {
      folder.deleteSync(recursive: true);
    } on FileSystemException {
      // The OS cleans temporary files.
    }
  }
}
