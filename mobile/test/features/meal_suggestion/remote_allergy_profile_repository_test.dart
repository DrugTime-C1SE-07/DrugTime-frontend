// RemoteAllergyProfileRepository: hồ sơ dị ứng thật cho gợi ý món ăn
// (task adhoc-20261118-health-profile-catalog, AC9, AC10; QD-40, QD-41).
import 'dart:convert';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/api/api_exception.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/repositories/remote_allergy_profile_repository.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/dietary_session.dart';
import 'package:drugtime_mobile/features/meal_suggestion/presentation/state/meal_plan_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'meal_test_helpers.dart';

Map<String, Object?> snapshot(Map<String, Object?> allergies) => {
      'revision': '7',
      'allergies': allergies,
      'conditions': {'status': 'unreported'},
    };

void main() {
  late List<http.Request> requests;

  RemoteAllergyProfileRepository repoReturning(Object body,
      {int status = 200}) {
    requests = [];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    return RemoteAllergyProfileRepository(ApiClient(
      baseUrl: Uri.parse('http://api.test'),
      httpClient: client,
      authTokenProvider: () async => 'token',
    ));
  }

  test('reported: tên danh mục từ catalog_items và mục tự nhập (AC9)',
      () async {
    final repo = repoReturning(snapshot({
      'status': 'reported',
      'catalog_ids': ['penicillin', 'retired_one'],
      'custom_names': ['Phấn hoa'],
      'catalog_items': [
        {'id': 'penicillin', 'category': 'drug', 'name': 'Penicillin'},
        {'id': 'retired_one', 'category': 'food', 'name': 'Mục đã ngừng dùng'},
      ],
    }));

    final profile = await repo.load();

    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/profile/health-setup');
    expect(profile.status, AllergyStatus.reported);
    expect(profile.catalogItems.map((i) => i.name),
        ['Penicillin', 'Mục đã ngừng dùng']);
    expect(profile.customItems, ['Phấn hoa']);
    // QD-41: khai báo gửi đi chỉ chứa tên dị ứng, không id hay định danh.
    expect(profile.toDeclaration()!.toJson(), {
      'none': false,
      'items': ['Penicillin', 'Mục đã ngừng dùng', 'Phấn hoa'],
    });
  });

  test('none_known → khai báo "không có"', () async {
    final profile =
        await repoReturning(snapshot({'status': 'none_known'})).load();
    expect(profile.status, AllergyStatus.noneKnown);
    expect(profile.toDeclaration()!.toJson(), {'none': true, 'items': []});
  });

  test('unreported → không có khai báo (AC10)', () async {
    final profile =
        await repoReturning(snapshot({'status': 'unreported'})).load();
    expect(profile.status, AllergyStatus.unreported);
    expect(profile.toDeclaration(), isNull);
  });

  test('thiếu catalog_items hoặc nhãn không khớp id → lỗi, không bỏ dị ứng',
      () async {
    final missing = repoReturning(snapshot({
      'status': 'reported',
      'catalog_ids': ['penicillin'],
      'custom_names': [],
    }));
    await expectLater(missing.load(), throwsFormatException);

    final mismatch = repoReturning(snapshot({
      'status': 'reported',
      'catalog_ids': ['penicillin', 'milk'],
      'custom_names': [],
      'catalog_items': [
        {'id': 'penicillin', 'category': 'drug', 'name': 'Penicillin'},
      ],
    }));
    await expectLater(mismatch.load(), throwsFormatException);
  });

  test('status lạ → lỗi', () async {
    await expectLater(repoReturning(snapshot({'status': 'maybe'})).load(),
        throwsFormatException);
  });

  test('API lỗi → ném ApiException (AC10)', () async {
    final repo = repoReturning({'detail': 'khong_co_quyen'}, status: 403);
    await expectLater(repo.load(), throwsA(isA<ApiException>()));
  });

  test('controller: tải hồ sơ lỗi → allergyFailed, không gọi API gợi ý (AC10)',
      () async {
    final meals = FakeMealRepository();
    final session = DietarySession.instance
      ..clear()
      ..restrictions = const DietaryDeclaration.none();
    final controller = MealPlanController(
      repository: meals,
      allergyRepository: repoReturning({'detail': 'oops'}, status: 500),
      session: session,
      now: () => DateTime.utc(2026, 11, 19, 4),
    )..bind('p1');

    await controller.loadAllergy();
    await controller.analyze();

    expect(controller.allergyFailed, isTrue);
    expect(controller.allergyReported, isFalse);
    expect(controller.canRequest, isFalse);
    expect(meals.calls, isEmpty);
  });
}
