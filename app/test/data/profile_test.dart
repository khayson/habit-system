import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/profile_view.dart';
import 'package:habit/sync/outbox_states.dart';

import '../support/contract_fixtures.dart';
import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// Phase 3b (A20): profile.update through LocalMutationService and the profile view, against
/// contract-fixtures/sync/profile_update_mutations.json and user_entity.json.
void main() {
  setUpAll(Device.loadZones);

  late FakeSyncServer server;
  late Device phone;

  setUp(() async {
    server = FakeSyncServer();
    phone = await Device(server).init();
  });
  tearDown(() => phone.db.close());

  ProfileView view() => ProfileView(phone.db, filesRoot: '/files');

  Map<String, Object?> wire(OutboxRow row) => {
    'mutation_id': row.mutationId,
    'entity': row.entity,
    'entity_id': row.entityId,
    'operation': row.operation,
    'base_version': row.baseVersion,
    'occurred_at': row.occurredAt,
    'captured_timezone': row.capturedTimezone,
    'local_date_hint': row.localDateHint,
    'payload': jsonDecode(row.payload),
  };

  test(
    'writes the profile_update_mutations.json mutation: all three keys, the user version',
    () async {
      final fixture = contractFixture('sync/profile_update_mutations.json');
      expect(fixture['suites'], contains('dart'));
      final expected = (fixture['accepted'] as Map)['mutation'] as Map<String, dynamic>;

      await phone.writer.updateProfile(name: 'Maya Chen', city: 'Accra', countryCode: 'GH');

      final row = (await phone.outbox()).single;
      final sent = wire(row);
      expect(sent.keys.toSet(), expected.keys.toSet());
      expect(
        [
          sent['entity'],
          sent['entity_id'],
          sent['operation'],
          sent['base_version'],
          sent['payload'],
        ],
        ['user', 'user-1', 'profile.update', expected['base_version'], expected['payload']],
      );
      expect(row.state, OutboxState.pending);
    },
  );

  test('null clears city and country, and they are still sent; input is trimmed', () async {
    await phone.writer.updateProfile(name: '  Maya  ', city: '   ', countryCode: null);

    final payload = jsonDecode((await phone.outbox()).single.payload) as Map;
    expect(payload, {'name': 'Maya', 'city': null, 'country_code': null});
  });

  test('a second unsent edit coalesces into the first and keeps its base version', () async {
    final first = await phone.writer.updateProfile(name: 'Maya', city: 'Accra', countryCode: 'GH');
    server.bumpUserVersion();
    await (phone.db.update(phone.db.syncState))
        .write(SyncStateCompanion(userPayload: Value(jsonEncode(server.user))));
    final second = await phone.writer.updateProfile(
      name: 'Maya',
      city: 'Kumasi',
      countryCode: 'GH',
    );

    final rows = await phone.outbox();
    expect(second, first);
    expect(rows, hasLength(1));
    expect((rows.single.baseVersion, jsonDecode(rows.single.payload)['city']), (1, 'Kumasi'));
  });

  test('the view shows the edit at once, then the confirmed profile after sync', () async {
    await phone.writer.updateProfile(name: 'Maya Chen', city: 'Accra', countryCode: 'GH');
    var state = (await view().load())!;
    expect(
      (state.name, state.city, state.countryCode, state.editQueued),
      ('Maya Chen', 'Accra', 'GH', true),
    );
    expect(state.unsynced, 1);

    await phone.sync(force: true);

    state = (await view().load())!;
    expect(
      (state.name, state.city, state.countryCode, state.editQueued, state.unsynced),
      ('Maya Chen', 'Accra', 'GH', false, 0),
    );
    expect((server.name, server.city, server.countryCode), ('Maya Chen', 'Accra', 'GH'));
  });

  test('a stale edit becomes a conflict for screen 18; nothing is lost', () async {
    await phone.writer.updateProfile(name: 'Maya Chen', city: null, countryCode: null);
    server.bumpUserVersion();

    await phone.sync(force: true);

    final row = (await phone.outbox()).single;
    expect(row.state, OutboxState.needsAttention);
    expect(jsonDecode(row.lastError!)['code'], 'version_conflict');
    final state = (await view().load())!;
    expect((state.editNeedsAttention, state.name), (true, 'Maya Chen'));
  });

  test('reads the user_entity.json fields, and tolerates them absent or with extras', () async {
    final fixture = contractFixture('sync/user_entity.json');
    expect(fixture['suites'], contains('dart'));
    final example = (fixture['example_3b'] as Map).cast<String, dynamic>();

    Future<ProfileState> withUser(Map<String, dynamic> user) async {
      await (phone.db.update(phone.db.syncState))
          .write(SyncStateCompanion(userPayload: Value(jsonEncode(user))));
      return (await view().load())!;
    }

    var state = await withUser({'id': 'user-1', 'name': 'Maya', 'version': 3, ...example});
    expect(
      (state.city, state.countryCode, state.avatarVersion, state.hasAvatar),
      (example['city'], example['country_code'], example['avatar_version'], example['has_avatar']),
    );

    // An older server: none of the 3b fields.
    state = await withUser({'id': 'user-1', 'name': 'Maya', 'version': 3});
    expect(
      (state.city, state.countryCode, state.avatarVersion, state.hasAvatar),
      (null, null, 0, false),
    );

    // A newer server: unknown fields are ignored, wrong types read as absent.
    state = await withUser({
      'name': 'Maya',
      'avatar_version': 'two',
      'has_avatar': 'yes',
      'pronouns': 'they/them',
      'frame': {'style': 'round'},
    });
    expect((state.avatarVersion, state.hasAvatar, state.name), (0, false, 'Maya'));
  });

  test('initials come from the first two words', () async {
    ProfileState named(String name) => ProfileState(
      name: name,
      email: null,
      city: null,
      countryCode: null,
      avatarVersion: 0,
      hasAvatar: false,
      editQueued: false,
      editNeedsAttention: false,
      photoPath: null,
      uploadPending: false,
      uploadRejected: false,
      unsynced: 0,
    );
    expect(named('Maya Chen').initials, 'MC');
    expect(named('  ama  ').initials, 'A');
    expect(named('Kwame Nkrumah Junior').initials, 'KN');
    expect(named('').initials, '');
  });
}
