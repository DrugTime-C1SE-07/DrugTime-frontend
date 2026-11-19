import '../entities/allergy_profile.dart';

/// Nguồn hồ sơ dị ứng của chính người dùng. Ở task 5.11 chỉ có bản mock; bản thật sẽ đọc
/// `GET /profile/health-setup` (màn gợi ý chỉ phụ thuộc interface này).
abstract interface class AllergyProfileRepository {
  Future<AllergyProfile> load();
}
