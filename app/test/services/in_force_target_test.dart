import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/provisional_type_rules.dart';
import 'package:habit/services/habit_actions.dart';

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// A one-tap type whose target is an amount: the only kind where the target a tap writes can
/// differ between definitions.
class _TapAmount extends QuantityRules {
  const _TapAmount();
  @override
  String get key => 'tap_amount';
  @override
  bool get oneTap => true;
}

Map<String, dynamic> _definition(int version, String from, String target) => {
  'version': version,
  'effective_date': from,
  'type': 'tap_amount',
  'target_value': target,
  'unit': 'glass',
  'category': 'health',
  'frequency_type': 'daily',
  'frequency_config': <String, dynamic>{},
};

/// Phase 4.2b (I2): the definition in force needs a clock, and a tap writes its target.
void main() {
  setUpAll(Device.loadZones);

  final payload = <String, dynamic>{
    'id': 'h1',
    'name': 'Water',
    'type': 'tap_amount',
    // The latest definition, starting tomorrow.
    'target_value': '2.000',
    'unit': 'glass',
    'start_local_date': '2026-05-01',
    'frequency_type': 'daily',
    'frequency_config': <String, dynamic>{},
    'archived_at': null,
    'definitions': [_definition(1, '2026-05-01', '1.000'), _definition(2, '2026-05-29', '2.000')],
    'active_ranges': [
      {'starts_on': '2026-05-01', 'ends_before': null},
    ],
  };

  test(
    'I2: inForceToday has no default: without a clock it is an error, not the first version',
    () {
      final unclocked = HabitView(
        payload: payload,
        confirmedVersion: 2,
        syncState: null,
        knownType: true,
      );
      expect(() => unclocked.inForceToday, throwsStateError);
      final clocked = HabitView(
        payload: payload,
        confirmedVersion: 2,
        syncState: null,
        knownType: true,
        today: LocalDate.parse('2026-05-28'),
      );
      expect(clocked.inForceToday!.wire['target_value'], '1.000');
    },
  );

  test('I2: a tap writes the target in force on that day, not the latest one', () async {
    final phone = await Device(FakeSyncServer()).init();
    addTearDown(phone.db.close);
    final actions = HabitActions(
      phone.writer,
      onLocalWrite: () {},
      types: ProvisionalTypeRegistry(const [_TapAmount()]),
      clock: () => phone.now,
    );
    final item = TodayItem(
      habit: HabitView(
        payload: payload,
        confirmedVersion: 2,
        syncState: null,
        knownType: true,
        today: LocalDate.parse('2026-05-28'),
      ),
      log: const LogView(
        habitId: 'h1',
        date: '2026-05-28',
        value: null,
        deleted: false,
        confirmedVersion: null,
        syncState: null,
      ),
      rules: const _TapAmount(),
      complete: false,
      attention: null,
    );
    await actions.toggle(item);
    final row = (await phone.outbox()).single;
    expect(row.payload, contains('"value":"1.000"'));
  });
}
