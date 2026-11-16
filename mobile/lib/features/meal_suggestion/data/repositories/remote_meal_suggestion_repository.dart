import 'dart:typed_data';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../../domain/repositories/meal_suggestion_repository.dart';
import '../models/meal_suggestion_mapper.dart';

/// Gọi Backend API (bất biến 1: không gọi Supabase hay kho ảnh trực tiếp).
///
/// Chỉ cache nội dung ảnh trong bộ nhớ (LRU); ảnh dùng chung, không phải dữ liệu sức khỏe.
/// Gợi ý không được cache hay lưu bền.
class RemoteMealSuggestionRepository implements MealSuggestionRepository {
  RemoteMealSuggestionRepository(this._api, {this.imageCacheSize = 40});

  final ApiClient _api;
  final int imageCacheSize;
  final _bytes = <int, Uint8List>{}; // giữ thứ tự chèn → LRU

  @override
  Future<MealSuggestionResult> suggest({
    required String patientId,
    required MealType mealType,
    required DietaryDeclaration allergies,
    required DietaryDeclaration restrictions,
    List<String> preferences = const [],
    int? previousSuggestionId,
  }) async {
    try {
      final json = await _api.postJson(
        '/patients/$patientId/meal-suggestions',
        body: MealSuggestionMapper.toRequestBody(
          mealType: mealType,
          allergies: allergies,
          restrictions: restrictions,
          preferences: preferences,
          previousSuggestionId: previousSuggestionId,
        ),
      );
      return MealSuggestionMapper.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (error) {
      throw MealSuggestionMapper.failureFrom(error);
    }
  }

  @override
  Future<List<MealDishImage>> imageStates(List<int> imageIds) async {
    if (imageIds.isEmpty) return const [];
    // `ApiClient.query` là Map nên không lặp được tham số; ghép thẳng vào path.
    final query = imageIds.take(20).map((id) => 'ids=$id').join('&');
    try {
      final json = await _api.getJson('/meal-images?$query') as Map<String, dynamic>;
      return (json['items'] as List)
          .map((i) => MealSuggestionMapper.imageFromJson(i as Map<String, dynamic>))
          .toList();
    } on ApiException catch (error) {
      throw MealSuggestionMapper.failureFrom(error);
    }
  }

  @override
  Future<Uint8List> imageBytes(MealDishImage image) async {
    final cached = _bytes.remove(image.imageId);
    if (cached != null) {
      _bytes[image.imageId] = cached; // đưa lên mới nhất
      return cached;
    }
    final url = image.url;
    if (!image.isReady || url == null || !url.startsWith('/meal-images/')) {
      throw const MealSuggestionFailure(MealFailureKind.unknown);
    }
    try {
      final bytes = await _api.getBytes(url);
      _bytes[image.imageId] = bytes;
      while (_bytes.length > imageCacheSize) {
        _bytes.remove(_bytes.keys.first);
      }
      return bytes;
    } on ApiException catch (error) {
      throw MealSuggestionMapper.failureFrom(error);
    }
  }
}
