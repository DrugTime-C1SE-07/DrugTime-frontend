import 'package:flutter/foundation.dart';

import '../../domain/entities/allergy_profile.dart';
import '../../domain/repositories/allergy_profile_repository.dart';

/// Mock hồ sơ dị ứng (task 5.11, Q3): nối `GET /profile/health-setup` ở task sau.
///
/// Mặc định `unreported`: không bao giờ tự coi người dùng là "không dị ứng" (QD-40).
/// Bản debug chọn kịch bản để chạy thử trên emulator:
/// `flutter run --dart-define=MEAL_ALLERGY_MOCK=reported` (`unreported` | `none_known` | `reported`).
/// Bản release luôn `unreported`.
class MockAllergyProfileRepository implements AllergyProfileRepository {
  MockAllergyProfileRepository({String? scenario})
      : _scenario = scenario ??
            (kDebugMode
                ? const String.fromEnvironment('MEAL_ALLERGY_MOCK')
                : 'unreported');

  final String _scenario;

  static const reportedSample = AllergyProfile(
    status: AllergyStatus.reported,
    catalogItems: [AllergyCatalogItem(id: 'shrimp', name: 'Tôm')],
    customItems: ['Đậu phộng'],
  );

  @override
  Future<AllergyProfile> load() async => switch (_scenario) {
        'none_known' => const AllergyProfile(status: AllergyStatus.noneKnown),
        'reported' => reportedSample,
        _ => const AllergyProfile.unreported(),
      };
}
