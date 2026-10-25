import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/router.dart';
import '../config/habit_tokens.dart';
import '../core/exceptions/app_exception.dart';
import '../core/file_sharer.dart';
import '../data/account_calendar.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/export_job.dart';
import '../providers/account_context.dart';
import '../widgets/habit_format.dart';
import '../widgets/habit_ui.dart';
import 'privacy_screen.dart';
import '../widgets/app_icons.dart';

/// Screens 29 (preparing, ready) and 30 (failed), A48. While open it asks GET /exports/{id}
/// every [pollEvery] for at most [pollFor], then stops quietly; the status stays on 21.
class ExportStatusScreen extends StatefulWidget {
  static const Duration pollEvery = Duration(seconds: 5);
  static const Duration pollFor = Duration(minutes: 2);

  final String exportId;
  final ExportJob? initial;
  final FileSharer sharer;
  final DateTime Function() clock;

  const ExportStatusScreen({
    super.key,
    required this.exportId,
    this.initial,
    required this.sharer,
    this.clock = DateTime.now,
  });

  @override
  State<ExportStatusScreen> createState() => _ExportStatusScreenState();
}

class _ExportStatusScreenState extends State<ExportStatusScreen> {
  late ExportJob? _job = widget.initial;
  Timer? _timer;
  int _polls = 0;
  bool _busy = false;
  String? _error;
  AccountCalendar? _calendar;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(ExportStatusScreen.pollEvery, (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final account = context.read<AccountContext?>();
      if (account == null) return;
      final calendar = await AccountCalendar.load(account.session.db, deviceNow: widget.clock());
      if (mounted) setState(() => _calendar = calendar);
      if (_job == null) _poll();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (++_polls > ExportStatusScreen.pollFor.inSeconds ~/ ExportStatusScreen.pollEvery.inSeconds) {
      _timer?.cancel();
      return;
    }
    final api = context.read<AccountContext?>()?.exportsApi;
    if (api == null) return;
    try {
      final job = await api.get(widget.exportId);
      if (!mounted) return;
      setState(() => _job = job);
      if (!job.status.pending) _timer?.cancel();
    } on Object {
      // A missed poll is tried again on the next tick.
    }
  }

  Future<void> _refetch() async {
    final api = context.read<AccountContext?>()?.exportsApi;
    try {
      final fresh = await api?.get(widget.exportId);
      if (mounted && fresh != null) setState(() => _job = fresh);
    } on Object {
      // The message already says what to do.
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.privacy);

  Future<void> _retry() async {
    final account = context.read<AccountContext>();
    final l10n = AppLocalizations.of(context);
    final format = _job?.format ?? 'json';
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final job = await account.exportsApi!.request(format);
      if (mounted) context.pushReplacement(Routes.exportStatus(job.id), extra: job);
    } on Object {
      if (mounted) setState(() => _error = l10n.privacyRequestError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(ExportJob job) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await downloadAndShare(context.read<AccountContext>(), job, widget.sharer);
    } on Object catch (e) {
      final expired = e is AppException && e.code == 'export_expired';
      if (mounted) {
        setState(() => _error = expired ? l10n.privacyDownloadExpired : l10n.privacyDownloadError);
      }
      // 6.1 review L4: the job now reads expired; fetch it once more.
      if (expired && mounted) await _refetch();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final tokens = HabitTokens.of(context);
    final words = ExportWords(l10n, HabitFormat(context), _calendar, widget.clock());
    final job = _job;
    final failed = job?.status == ExportStatus.failed;
    final ready = job?.status == ExportStatus.ready;
    final kind = words.kind(job?.format ?? 'json');
    final when = words.when(job?.requestedAt);
    final muted = text.bodyMedium?.copyWith(color: tokens.muted);

    final children = failed
        ? <Widget>[
            ScreenHeader(
              title: l10n.exportFailedTitle,
              subtitle: l10n.exportFailedSubtitle,
              onBack: _back,
            ),
            InfoCard(
              title: l10n.exportFailedCardTitle,
              body: l10n.exportFailedCardBody,
              tone: Tone.error,
              icon: AppIcons.clock,
            ),
            const SizedBox(height: HabitSpace.s24),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.exportFailedJob(kind), style: text.titleMedium),
                  const SizedBox(height: HabitSpace.s8),
                  Text(l10n.exportRequestFrom(when), style: muted),
                ],
              ),
            ),
            const SizedBox(height: HabitSpace.s48),
            PrimaryButton(label: l10n.exportRetry, loading: _busy, onPressed: _retry),
            const SizedBox(height: HabitSpace.s12),
            tonalButton(label: l10n.exportBackToPrivacy, onPressed: _back),
          ]
        : <Widget>[
            ScreenHeader(
              title: l10n.exportPreparingTitle,
              subtitle: l10n.exportPreparingSubtitle,
              onBack: _back,
            ),
            InfoCard(
              title: ready ? l10n.exportReadyTitle : l10n.exportQueuedTitle,
              body: ready ? l10n.exportReadyBody(kind, when) : l10n.exportQueuedBody(kind, when),
              tone: ready ? Tone.positive : Tone.info,
              icon: ready ? AppIcons.done : AppIcons.clock,
            ),
            const SizedBox(height: HabitSpace.s24),
            InfoCard(title: l10n.exportIncludesTitle, body: l10n.exportIncludesBody),
            const SizedBox(height: HabitSpace.s24),
            Text(l10n.exportLeaveNote, style: muted),
            const SizedBox(height: HabitSpace.s48),
            if (ready) ...[
              PrimaryButton(
                label: l10n.privacyDownload,
                loading: _busy,
                onPressed: () => _download(job!),
              ),
              const SizedBox(height: HabitSpace.s12),
              tonalButton(label: l10n.exportBackToPrivacy, onPressed: _back),
            ] else
              PrimaryButton(label: l10n.exportBackToPrivacy, onPressed: _back),
            const SizedBox(height: HabitSpace.s16),
            Text(l10n.exportReadyFooter, style: text.bodySmall?.copyWith(color: tokens.muted)),
          ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HabitSpace.margin),
          children: [
            ...children,
            if (_error != null) ...[
              const SizedBox(height: HabitSpace.s12),
              Semantics(liveRegion: true, child: Text(_error!, style: muted)),
            ],
          ],
        ),
      ),
    );
  }
}
