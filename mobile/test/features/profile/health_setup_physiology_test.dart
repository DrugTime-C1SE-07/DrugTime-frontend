import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/profile/data/models/profile_api_mapper.dart';
import 'package:drugtime_mobile/features/profile/data/repositories/remote_health_setup_repository.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/condition.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_setup.dart';
import 'package:drugtime_mobile/features/profile/domain/repositories/health_setup_repository.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/health_setup_status_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _none = HealthSetupStep<int>(HealthSetupStatus.noneKnown);
const _unreported = HealthSetupStep<int>(HealthSetupStatus.unreported);

HealthSetupSnapshot _snap(
        {HealthSetupStatus allergies = HealthSetupStatus.noneKnown,
        HealthSetupStep<int> conditions = _none,
        HealthSetupStep<int> physiological = _none}) =>
    HealthSetupSnapshot(
        '1', HealthSetupStep<String>(allergies), conditions, physiological);

void main() {
  group('isComplete (AC2, AC26)', () {
    test('every step answered is complete for any gender', () {
      expect(_snap().isComplete(gender: 'nu'), isTrue);
      expect(_snap().isComplete(gender: null), isTrue);
    });
    test('an unanswered physiological step blocks women and unknown gender',
        () {
      final s = _snap(physiological: _unreported);
      expect(s.isComplete(gender: 'nu'), isFalse);
      expect(s.isComplete(gender: 'khac'), isFalse);
      expect(s.isComplete(gender: null), isFalse);
    });
    test('men are not asked the physiological step', () {
      expect(
          _snap(physiological: _unreported).isComplete(gender: 'nam'), isTrue);
    });
    test('unanswered allergies or conditions block everyone', () {
      expect(
          _snap(allergies: HealthSetupStatus.unreported)
              .isComplete(gender: 'nam'),
          isFalse);
      expect(_snap(conditions: _unreported).isComplete(gender: 'nam'), isFalse);
    });
  });

  group('category mapping (AC16)', () {
    test('profile links and catalog items carry their category', () {
      final profile = ProfileApiMapper.profile({
        'full_name': 'A',
        'date_of_birth': null,
        'gender': 'female',
        'email': null,
        'phone_number': null,
        'conditions': [
          {
            'id': 1,
            'condition_id': 2,
            'condition_name': 'Đái tháo đường type 2',
            'subtype': null,
            'stage': null,
            'category': 'chronic_disease'
          },
          {
            'id': 2,
            'condition_id': 3,
            'condition_name': 'Đang mang thai',
            'subtype': null,
            'stage': null,
            'category': 'physiological_state'
          },
        ]
      });
      expect(profile.chronicConditions.map((c) => c.conditionId), [2]);
      expect(profile.conditions.last.category,
          ConditionCategory.physiologicalState);
      expect(profile.isMale, isFalse);
      final page = ProfileApiMapper.page({
        'items': [
          {'id': 3, 'name': 'Đang mang thai', 'category': 'physiological_state'}
        ],
        'total': 1,
        'offset': 0
      });
      expect(page.items.single.category, ConditionCategory.physiologicalState);
    });
    test('unknown category is rejected, missing defaults to chronic', () {
      expect(() => ConditionCategory.fromApi('other'), throwsFormatException);
      expect(ConditionCategory.fromApi(null), ConditionCategory.chronicDisease);
      expect(const HealthProfile(gender: 'nam').isMale, isTrue);
    });
  });

  group('RemoteHealthSetupRepository physiological step (AC13b, AC25)', () {
    late HttpServer server;
    late RemoteHealthSetupRepository repo;
    late List<(String, String, Object?)> calls;
    late Object? response;

    setUp(() async {
      calls = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = await utf8.decodeStream(request);
        calls.add((
          request.method,
          request.uri.path,
          body.isEmpty ? null : jsonDecode(body)
        ));
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      repo = RemoteHealthSetupRepository(ApiClient(
          baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
          authTokenProvider: () async => 'session'));
    });
    tearDown(() => server.close(force: true));

    test('reads reported physiological states without custom names', () async {
      response = {
        'revision': '4',
        'allergies': {'status': 'none_known'},
        'conditions': {'status': 'none_known'},
        'physiological_states': {
          'status': 'reported',
          'catalog_ids': [3, 4]
        },
      };
      final snapshot = await repo.read();
      expect(snapshot.physiological.status, HealthSetupStatus.reported);
      expect(snapshot.physiological.ids, [3, 4]);
      expect(snapshot.physiological.names, isEmpty);
    });

    test('an older backend without the step reads as unreported', () async {
      response = {
        'revision': '1',
        'allergies': {'status': 'unreported'},
        'conditions': {'status': 'unreported'},
      };
      expect((await repo.read()).physiological.status,
          HealthSetupStatus.unreported);
    });

    test('saves only the physiological step, never custom names', () async {
      response = {
        'revision': '5',
        'allergies': {'status': 'none_known'},
        'conditions': {'status': 'none_known'},
        'physiological_states': {'status': 'none_known'},
      };
      final saved = await repo.save('4', physiological: _none);
      expect(saved.physiological.status, HealthSetupStatus.noneKnown);
      expect(calls.single.$3, {
        'revision': '4',
        'physiological_states': {'status': 'none_known'}
      });
      await repo.save('5',
          physiological:
              const HealthSetupStep<int>(HealthSetupStatus.reported, ids: [3]));
      expect(calls.last.$3, {
        'revision': '5',
        'physiological_states': {
          'status': 'reported',
          'catalog_ids': [3]
        }
      });
    });

    test('condition catalog options carry the API category', () async {
      response = {
        'items': [
          {
            'id': 2,
            'name': 'Đái tháo đường type 2',
            'category': 'chronic_disease'
          },
          {
            'id': 3,
            'name': 'Đang mang thai',
            'category': 'physiological_state'
          },
        ],
        'total': 2,
        'limit': 100,
        'offset': 0
      };
      final options = await repo.conditions();
      expect(options.map((o) => o.category),
          ['chronic_disease', 'physiological_state']);
    });
  });

  group('HealthSetupStatusController (AC3, AC11)', () {
    test('reload, apply and clear', () async {
      final repo = _FakeRepo();
      final controller = HealthSetupStatusController(repo);
      await controller.reload();
      expect(controller.snapshot?.revision, '1');
      expect(controller.conditionOptions, hasLength(1));
      controller.apply(_snap().copyRevision('9'));
      expect(controller.snapshot?.revision, '9');
      controller.clear();
      expect(controller.snapshot, isNull);
      expect(controller.conditionOptions, isEmpty);
    });

    test('a failed read drops the snapshot and reports failure', () async {
      final repo = _FakeRepo();
      final controller = HealthSetupStatusController(repo);
      await controller.reload();
      repo.fail = true;
      await controller.reload();
      expect(controller.snapshot, isNull);
      expect(controller.failed, isTrue);
      expect(controller.loading, isFalse);
    });

    test('without a repository nothing is loaded', () async {
      final controller = HealthSetupStatusController(null);
      await controller.reload();
      expect(controller.available, isFalse);
      expect(controller.snapshot, isNull);
    });
  });
}

extension on HealthSetupSnapshot {
  HealthSetupSnapshot copyRevision(String revision) =>
      HealthSetupSnapshot(revision, allergies, conditions, physiological);
}

class _FakeRepo implements HealthSetupRepository {
  bool fail = false;

  @override
  Future<HealthSetupSnapshot> read() async {
    if (fail) throw StateError('offline');
    return _snap();
  }

  @override
  Future<List<HealthSetupOption<String>>> allergens() async =>
      const [HealthSetupOption('milk', 'Sữa', category: 'food')];

  @override
  Future<List<HealthSetupOption<int>>> conditions() async => const [
        HealthSetupOption(2, 'Đái tháo đường', category: 'chronic_disease')
      ];

  @override
  Future<HealthSetupSnapshot> save(String revision,
          {HealthSetupStep<String>? allergies,
          HealthSetupStep<int>? conditions,
          HealthSetupStep<int>? physiological}) async =>
      _snap();
}
