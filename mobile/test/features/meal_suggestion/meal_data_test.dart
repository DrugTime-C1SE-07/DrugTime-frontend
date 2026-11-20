// Domain + data của gợi ý bữa ăn (task 5.11): AC3, AC4, AC6, AC9, AC14, AC16, AC18, AC27.
import 'dart:convert';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/models/meal_suggestion_mapper.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/repositories/mock_allergy_profile_repository.dart';
import 'package:drugtime_mobile/features/meal_suggestion/data/repositories/remote_meal_suggestion_repository.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/allergy_profile.dart';
import 'package:drugtime_mobile/features/meal_suggestion/domain/entities/meal_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _dishJson(String name, {Object? image, bool isNew = true}) => {
      'name': name,
      'dish_type': 'com',
      'is_new': isNew,
      'tags': ['Ít muối'],
      'kcal_estimate': 480,
      'cook_minutes': 20,
      'image': image,
      'benefits': [
        {
          'text': 'Ít muối',
          'related_to': {'type': 'condition', 'label': 'Tăng huyết áp'}
        },
        {
          'text': 'Nhiều xơ',
          'related_to': {'type': 'general', 'label': null}
        },
      ],
      'ingredients': [
        {'name': 'Gạo lứt', 'amount': '60 g', 'group': 'chinh', 'use_sparingly': false},
        {'name': 'Muối', 'amount': '¼ thìa', 'group': 'gia_vi', 'use_sparingly': true},
      ],
    };

final _responseJson = {
  'suggestion_id': 3052,
  'meal_type': 'trua',
  'suggestions': [
    _dishJson('Cá basa hấp gừng'),
    _dishJson('Bún cá', isNew: false, image: {
      'image_id': 57,
      'status': 'ready',
      'url': '/meal-images/57',
      'attribution': {
        'provider': 'pixabay',
        'photographer_name': 'Trần Thị B',
        'photographer_url': 'https://pixabay.com/users/example-b-222222/',
        'source_url': 'https://pixabay.com/photos/example-222/',
      },
    }),
  ],
  'food_check': {
    'status': 'co_tuong_tac',
    'warnings': [
      {
        'rule_id': 81,
        'version_id': 930,
        'ingredient': {'id': 620, 'standard_name': 'Losartan'},
        'food_to_avoid': 'Thực phẩm giàu kali',
        'severity_level': 2,
        'reason': 'Có thể làm tăng kali máu.',
        'source': 'Dược thư',
      }
    ],
  },
  'disclaimer': 'Lời miễn trừ',
  'refreshes_remaining': 1,
  'created_at': '2026-11-16T11:32:40+07:00',
};

void main() {
  group('AllergyProfile (AC3, AC4)', () {
    test('mock mặc định unreported → không có khai báo, không gọi API', () async {
      final profile = await MockAllergyProfileRepository().load();
      expect(profile.status, AllergyStatus.unreported);
      expect(profile.toDeclaration(), isNull);
    });

    test('reported: tên danh mục + tự nhập, none=false', () async {
      final profile = await MockAllergyProfileRepository(scenario: 'reported').load();
      final d = profile.toDeclaration()!;
      expect(d.toJson(), {'none': false, 'items': ['Tôm', 'Đậu phộng']});
    });

    test('none_known → none=true, items rỗng', () async {
      final profile =
          await MockAllergyProfileRepository(scenario: 'none_known').load();
      expect(profile.toDeclaration()!.toJson(), {'none': true, 'items': <String>[]});
    });

    test('reported rỗng hoặc trùng được làm sạch; rỗng hẳn coi như chưa khai', () {
      const dup = AllergyProfile(
        status: AllergyStatus.reported,
        catalogItems: [AllergyCatalogItem(id: '1', name: 'Tôm')],
        customItems: [' tôm ', ' ', 'Cua'],
      );
      expect(dup.toDeclaration()!.items, ['Tôm', 'Cua']);
      expect(const AllergyProfile(status: AllergyStatus.reported).toDeclaration(),
          isNull);
    });
  });

  group('MealSuggestionMapper (AC6, AC14)', () {
    test('response contract → entity', () {
      final r = MealSuggestionMapper.fromJson(
          jsonDecode(jsonEncode(_responseJson)) as Map<String, dynamic>);
      expect(r.suggestionId, 3052);
      expect(r.refreshesRemaining, 1);
      expect(r.dishes.map((d) => d.isNew), [true, false]);
      expect(r.dishes.first.image, isNull);
      final image = r.dishes[1].image!;
      expect(image.isReady, isTrue);
      expect(image.attribution!.photographerName, 'Trần Thị B');
      expect(r.dishes.first.benefits.last.label, isNull);
      expect(r.dishes.first.mainIngredients.single.name, 'Gạo lứt');
      expect(r.dishes.first.seasonings.single.useSparingly, isTrue);
      expect(r.foodCheck.status, FoodCheckStatus.coTuongTac);
    });

    test('dish_type lạ → khac', () {
      final json = _dishJson('X')..['dish_type'] = 'mon_moi_sau_nay';
      expect(MealSuggestionMapper.dishFromJson(json).dishType, MealDishType.khac);
    });

    test('request body có/không có previous_suggestion_id', () {
      final body = MealSuggestionMapper.toRequestBody(
        mealType: MealType.toi,
        allergies: const DietaryDeclaration.items(['Tôm']),
        restrictions: const DietaryDeclaration.none(),
        preferences: const ['Ít cay'],
      );
      expect(body, {
        'meal_type': 'toi',
        'allergies': {'none': false, 'items': ['Tôm']},
        'dietary_restrictions': {'none': true, 'items': <String>[]},
        'preferences': ['Ít cay'],
      });
      final refresh = MealSuggestionMapper.toRequestBody(
        mealType: MealType.toi,
        allergies: const DietaryDeclaration.none(),
        restrictions: const DietaryDeclaration.none(),
        previousSuggestionId: 3051,
      );
      expect(refresh['previous_suggestion_id'], 3051);
    });
  });

  group('RemoteMealSuggestionRepository (AC9, AC16, AC18, AC27)', () {
    late List<http.Request> requests;
    late http.Response Function(http.Request) handler;

    RemoteMealSuggestionRepository repo() {
      requests = [];
      final client = MockClient((request) async {
        requests.add(request);
        return handler(request);
      });
      return RemoteMealSuggestionRepository(ApiClient(
          baseUrl: Uri.parse('https://api.example'), httpClient: client));
    }

    Future<MealSuggestionResult> suggest(RemoteMealSuggestionRepository r,
            {int? previous}) =>
        r.suggest(
          patientId: 'p1',
          mealType: MealType.trua,
          allergies: const DietaryDeclaration.items(['Tôm']),
          restrictions: const DietaryDeclaration.none(),
          previousSuggestionId: previous,
        );

    test('POST đúng path, body có previous_suggestion_id; chỉ gọi Backend API', () async {
      handler = (_) => http.Response.bytes(utf8.encode(jsonEncode(_responseJson)), 200,
          headers: {'content-type': 'application/json'});
      final r = repo();
      await suggest(r, previous: 3051);
      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), 'https://api.example/patients/p1/meal-suggestions');
      expect(jsonDecode(req.body)['previous_suggestion_id'], 3051);
    });

    final cases = <(int, String, MealFailureKind)>[
      (403, 'consent_revoked', MealFailureKind.consentRevoked),
      (403, 'khong_co_quyen', MealFailureKind.forbidden),
      (422, 'previous_suggestion_not_found', MealFailureKind.previousNotFound),
      (429, 'refresh_limit_reached', MealFailureKind.refreshLimit),
      (502, 'llm_invalid_output', MealFailureKind.llmInvalidOutput),
      (503, 'llm_disabled', MealFailureKind.llmDisabled),
      (503, 'llm_unavailable', MealFailureKind.llmUnavailable),
      (503, 'service_unavailable', MealFailureKind.serviceUnavailable),
    ];
    for (final (status, detail, kind) in cases) {
      test('$status $detail → $kind', () async {
        handler = (_) => http.Response(jsonEncode({'detail': detail}), status);
        await expectLater(
          suggest(repo()),
          throwsA(isA<MealSuggestionFailure>().having((f) => f.kind, 'kind', kind)),
        );
      });
    }

    test('lỗi mạng → network, có thể thử lại; llm_disabled không thử lại', () async {
      final client = MockClient((_) => throw http.ClientException('down'));
      final r = RemoteMealSuggestionRepository(
          ApiClient(baseUrl: Uri.parse('https://api.example'), httpClient: client));
      await expectLater(
        suggest(r),
        throwsA(isA<MealSuggestionFailure>()
            .having((f) => f.kind, 'kind', MealFailureKind.network)
            .having((f) => f.canRetry, 'canRetry', true)),
      );
      expect(const MealSuggestionFailure(MealFailureKind.llmDisabled).canRetry, isFalse);
    });

    test('trạng thái ảnh: lặp tham số ids; bytes cache theo id', () async {
      handler = (req) => req.url.path == '/meal-images'
          ? http.Response(
              jsonEncode({
                'items': [
                  {'image_id': 42, 'status': 'pending', 'url': null, 'attribution': null}
                ]
              }),
              200)
          : http.Response.bytes([1, 2, 3], 200);
      final r = repo();
      final states = await r.imageStates([42, 57]);
      expect(requests.single.url.toString(),
          'https://api.example/meal-images?ids=42&ids=57');
      expect(states.single.status, MealImageStatus.pending);

      const ready = MealDishImage(
          imageId: 57, status: MealImageStatus.ready, url: '/meal-images/57');
      expect(await r.imageBytes(ready), [1, 2, 3]);
      expect(await r.imageBytes(ready), [1, 2, 3]);
      expect(requests.where((q) => q.url.path == '/meal-images/57'), hasLength(1));
      // Không bao giờ gọi URL ngoài Backend API.
      expect(requests.every((q) => q.url.host == 'api.example'), isTrue);
    });

    test('ảnh có url lạ (không phải /meal-images/) bị từ chối, không gọi mạng (AC9)',
        () async {
      handler = (_) => http.Response('', 200);
      final r = repo();
      const foreign = MealDishImage(
          imageId: 1,
          status: MealImageStatus.ready,
          url: 'https://xyz.supabase.co/storage/v1/object/1.jpg');
      await expectLater(r.imageBytes(foreign), throwsA(isA<MealSuggestionFailure>()));
      expect(requests, isEmpty);
    });
  });

  test('tab mặc định theo giờ Việt Nam', () {
    DateTime vn(int h, int m) => DateTime.utc(2026, 11, 16, h, m).subtract(const Duration(hours: 7));
    expect(MealType.forVietnamTime(vn(9, 59)), MealType.sang);
    expect(MealType.forVietnamTime(vn(10, 0)), MealType.trua);
    expect(MealType.forVietnamTime(vn(15, 59)), MealType.trua);
    expect(MealType.forVietnamTime(vn(16, 0)), MealType.toi);
  });
}
