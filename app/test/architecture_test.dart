import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Source-level guards for rules the analyzer cannot express.

/// Raw database construction. Only lib/data/database_opener.dart may do this (ADR 0001).
final rawDatabaseOpen = RegExp(r'\bNativeDatabase\b|\bdriftDatabase\s*\(|\bDriftIsolate\b');

/// A52: Material and toast-package messages; the app has its own toast.
final snackOrToast = RegExp(
  r'\bSnackBar\w*\b|\bScaffoldMessenger\b|\bshowSnackBar\b|package:(fluttertoast|another_flushbar|toastification|bot_toast|oktoast)',
);

/// A52: icons drawn other than through the registry (lib/widgets/app_icons.dart).
final iconOutsideRegistry = RegExp(r'(?<![A-Za-z_])Icons\.|\bHugeIcons?\b|package:hugeicons');

Map<String, String> dartSources(String dir) {
  return {
    for (final file in Directory(dir).listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
        p.posix.joinAll(p.split(p.relative(file.path))): _stripComments(file.readAsStringSync()),
  };
}

/// Words of every identifier (camelCase and snake_case split), lower-cased.
Iterable<String> identifierWords(String code) sync* {
  final words = RegExp(r'[A-Z]?[a-z]+|[A-Z]+(?![a-z])|\d+');
  for (final identifier in RegExp(r'[A-Za-z_][A-Za-z0-9_]*').allMatches(code)) {
    for (final word in words.allMatches(identifier.group(0)!)) {
      yield word.group(0)!.toLowerCase();
    }
  }
}

const _rewardWords = {'streak', 'streaks', 'xp', 'freeze', 'freezes', 'level', 'levels'};

bool mentionsRewards(String code) => identifierWords(code).any(_rewardWords.contains);

String _stripComments(String source) =>
    source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  group('habit types live in the registry (invariant 14, A21)', () {
    final typeKey = RegExp(r'''['"](binary|quantity|duration)['"]''');

    test('self-test', () {
      expect(typeKey.hasMatch("case 'quantity':"), isTrue);
      expect(typeKey.hasMatch('final q = quantity;'), isFalse);
    });

    // The provisional rules and the type-widget registry (4.2b) may name a type; nothing else.
    const allowed = {
      'lib/domain/provisional_type_rules.dart',
      'lib/habit_types/habit_type_ui.dart',
    };
    List<String> offenders(Map<String, String> sources) => sources.entries
        .where((e) => !allowed.contains(e.key))
        .where((e) => typeKey.hasMatch(e.value))
        .map((e) => e.key)
        .toList();

    test('self-test: a planted literal outside the registry is caught', () {
      expect(
        offenders({
          'lib/screens/edit_habit_screen.dart': "if (habit.type == 'duration') {}",
          'lib/habit_types/habit_type_ui.dart': "const key = 'duration';",
        }),
        ['lib/screens/edit_habit_screen.dart'],
      );
    });

    test('type keys appear only in the provisional rules and the type-widget registry', () {
      expect(offenders(dartSources('lib')), isEmpty);
    });
  });

  group('the client never evaluates rewards (invariant 9)', () {
    test('self-test', () {
      expect(mentionsRewards('int currentStreak = 0;'), isTrue);
      expect(mentionsRewards('computeXp()'), isTrue);
      expect(mentionsRewards('final XP_TOTAL = 1;'), isTrue);
      expect(mentionsRewards('nextLevelThreshold'), isTrue);
      expect(mentionsRewards('final weekly = RegExp(expected);'), isFalse);
    });

    test('lib/domain has no streak, XP, freeze or level code', () {
      final offenders = dartSources('lib/domain').entries
          .where((e) => mentionsRewards(e.value))
          .map((e) => e.key)
          .toList();

      expect(offenders, isEmpty);
    });
  });

  group('contract fixtures', () {
    // fixture (folder/name) -> the Dart test that consumes it.
    const dartConsumers = {
      'domain/progress': 'test/domain/provisional_progress_test.dart',
      'domain/weekly': 'test/domain/provisional_progress_test.dart',
      'domain/day_resolution': 'test/domain/day_resolution_test.dart',
      'domain/calendar_changes': 'test/domain/calendar_changes_test.dart',
      'domain/calendar_boundaries': 'test/domain/calendar_boundaries_test.dart',
      'domain/schedule': 'test/domain/habit_schedule_test.dart',
      'domain/reminder_schedule': 'test/notifications/reminder_planner_test.dart',
      'sync/ack_server_error': 'test/sync/sync_fixtures_test.dart',
      'sync/bootstrap_entities': 'test/sync/sync_fixtures_test.dart',
      'sync/ack_restored': 'test/sync/sync_fixtures_test.dart',
      'sync/ack_merged_entity_id': 'test/sync/sync_fixtures_test.dart',
      'sync/ack_delete_natural_key': 'test/sync/sync_fixtures_test.dart',
      'sync/log_backdate_payload': 'test/sync/sync_fixtures_test.dart',
      'sync/reward_state_entity': 'test/sync/sync_fixtures_test.dart',
      'sync/ack_xp_delta_wire': 'test/sync/ack_watch_test.dart',
      'rewards/rewards_response': 'test/services/rewards_service_test.dart',
      'rewards/freezes_response': 'test/services/rewards_service_test.dart',
      'insights/insights_responses': 'test/services/insights_service_test.dart',
      'exports/export_job': 'test/services/export_service_test.dart',
      'sync/reminder_mutations': 'test/sync/reminder_sync_test.dart',
      'sync/reminder_entity': 'test/sync/reminder_sync_test.dart',
      'auth/register_request': 'test/services/auth_service_test.dart',
      'auth/delete_me': 'test/services/auth_service_test.dart',
      'auth/account_deletion_status': 'test/services/auth_service_test.dart',
      'auth/forgot_password': 'test/services/auth_service_test.dart',
      'auth/reset_password': 'test/services/auth_service_test.dart',
      'sync/profile_update_mutations': 'test/data/profile_test.dart',
      'sync/user_entity': 'test/data/profile_test.dart',
      'habit/habit_mutations': 'test/sync/habit_acks_test.dart',
      'habit/habit_delete': 'test/data/habit_delete_test.dart',
      'habit/icons': 'test/domain/habit_icons_test.dart',
    };

    test('every domain, sync, auth, habit, rewards, insights and exports fixture that names the dart suite has a consumer', () {
      final named = <String>{};
      for (final folder in ['domain', 'sync', 'auth', 'habit', 'rewards', 'insights', 'exports']) {
        for (final file in Directory(
          p.join('..', 'contract-fixtures', folder),
        ).listSync().whereType<File>()) {
          final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          if ((json['suites'] as List<dynamic>).contains('dart')) {
            named.add('$folder/${p.basenameWithoutExtension(file.path)}');
          }
        }
      }

      expect(named, dartConsumers.keys.toSet());
      dartConsumers.forEach((fixture, test) {
        final file = File(test);
        expect(file.existsSync(), isTrue, reason: '$test is missing');
        expect(file.readAsStringSync(), contains(fixture.split('/').last), reason: test);
      });
    });
  });

  group('database opener guard', () {
    test('self-test: the pattern catches every raw way to open drift', () {
      expect(rawDatabaseOpen.hasMatch('NativeDatabase(File(path))'), isTrue);
      expect(rawDatabaseOpen.hasMatch('NativeDatabase.createInBackground(f)'), isTrue);
      expect(rawDatabaseOpen.hasMatch("driftDatabase (name: 'x')"), isTrue);
      expect(rawDatabaseOpen.hasMatch('DriftIsolate.spawn(open)'), isTrue);
      expect(rawDatabaseOpen.hasMatch('openAccountDatabase(id)'), isFalse);
      expect(_stripComments('// NativeDatabase in a comment'), isNot(contains('NativeDatabase')));
    });

    test('only lib/data/database_opener.dart opens a database', () {
      final offenders = dartSources('lib').entries
          .where((e) => e.key != 'lib/data/database_opener.dart')
          .where((e) => rawDatabaseOpen.hasMatch(e.value))
          .map((e) => e.key)
          .toList();

      expect(offenders, isEmpty);
    });

    test('the opener itself still uses the shared-server path', () {
      final opener = dartSources('lib')['lib/data/database_opener.dart']!;
      expect(opener, contains('shareAcrossIsolates: true'));
    });
  });

  group('A52: messages and icons', () {
    test('self-test', () {
      expect(snackOrToast.hasMatch('SnackBar(content: x)'), isTrue);
      expect(snackOrToast.hasMatch('ScaffoldMessenger.of(context)'), isTrue);
      expect(snackOrToast.hasMatch("import 'package:fluttertoast/fluttertoast.dart';"), isTrue);
      expect(snackOrToast.hasMatch('AppToast.show(context)'), isFalse);
      expect(iconOutsideRegistry.hasMatch('Icon(Icons.check)'), isTrue);
      expect(iconOutsideRegistry.hasMatch('HugeIcon(icon: x)'), isTrue);
      expect(iconOutsideRegistry.hasMatch('AppIcon(AppIcons.check)'), isFalse);
    });

    test('no snackbar, ScaffoldMessenger or toast package in app/lib', () {
      final offenders = dartSources('lib').entries
          .where((e) => snackOrToast.hasMatch(e.value))
          .map((e) => e.key)
          .toList();
      expect(offenders, isEmpty);
    });

    test('every icon comes through lib/widgets/app_icons.dart', () {
      final offenders = dartSources('lib').entries
          .where((e) => e.key != 'lib/widgets/app_icons.dart')
          .where((e) => iconOutsideRegistry.hasMatch(e.value))
          .map((e) => e.key)
          .toList();
      expect(offenders, isEmpty);
    });
  });
}
