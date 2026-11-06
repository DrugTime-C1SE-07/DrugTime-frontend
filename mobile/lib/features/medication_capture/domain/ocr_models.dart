enum OcrMatchStatus { matched, lowConfidence, noMatch }

enum OcrStage { preparing, recognizing, matching, result, failure, closed }

enum OcrFailureKind {
  invalidImage,
  expiredImage,
  noText,
  textTooLong,
  unsupported,
  recognition,
  unauthorized,
  validation,
  network,
  server,
  badResponse,
  unavailable,
  cleanup,
}

class OcrFailure implements Exception {
  const OcrFailure(this.kind);
  final OcrFailureKind kind;
  bool get canRetry => const {
        OcrFailureKind.recognition,
        OcrFailureKind.network,
        OcrFailureKind.server,
        OcrFailureKind.unavailable,
      }.contains(kind);
  String get message => switch (kind) {
        OcrFailureKind.invalidImage => 'Không mở được ảnh. Hãy chụp lại.',
        OcrFailureKind.expiredImage => 'Ảnh không còn khả dụng. Hãy chụp lại.',
        OcrFailureKind.noText =>
          'Chưa đọc được chữ trên bao bì. Hãy chụp rõ tên thuốc.',
        OcrFailureKind.textTooLong =>
          'Ảnh có quá nhiều chữ. Hãy chọn vùng tên và hàm lượng thuốc.',
        OcrFailureKind.unsupported => 'Nhận diện bao bì hiện hỗ trợ Android.',
        OcrFailureKind.recognition =>
          'Chưa đọc được ảnh. Bạn có thể thử lại hoặc chụp lại.',
        OcrFailureKind.unauthorized =>
          'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.',
        OcrFailureKind.validation =>
          'Chưa xử lý được thông tin trên ảnh. Hãy chụp lại.',
        OcrFailureKind.network =>
          'Không kết nối được. Kiểm tra mạng rồi thử lại.',
        OcrFailureKind.server =>
          'Chưa tìm được thuốc lúc này. Hãy thử lại sau.',
        OcrFailureKind.badResponse => 'Kết quả chưa hợp lệ. Hãy thử lại sau.',
        OcrFailureKind.unavailable => 'Chưa kết nối được dịch vụ tìm thuốc.',
        OcrFailureKind.cleanup => 'Chưa dọn xong ảnh tạm. Hãy thử dọn lại.',
      };
  @override
  String toString() => 'OcrFailure(${kind.name})';
}

class OcrCandidate {
  const OcrCandidate(
      {required this.id,
      required this.name,
      required this.activeIngredient,
      required this.strengthText,
      required this.dosageForm,
      required this.hasActiveIngredients,
      required this.score});
  final int id;
  final String name;
  final String? activeIngredient, strengthText, dosageForm;
  final bool hasActiveIngredients;
  final double score;
}

class OcrMatchResult {
  OcrMatchResult(
      {required this.status,
      required List<OcrCandidate> items,
      required this.preselectedId,
      required this.suggestedQuery,
      required List<String> reasons})
      : items = List.unmodifiable(items),
        reasons = List.unmodifiable(reasons);
  final OcrMatchStatus status;
  final List<OcrCandidate> items;
  final int? preselectedId;
  final String? suggestedQuery;
  final List<String> reasons;

  static const reasonValues = {
    'strength_unverified',
    'strength_unparsed',
    'multiple_strengths',
    'strength_conflict',
    'strength_mismatch',
    'lasa_close',
    'tie',
    'truncated',
    'below_threshold',
  };

  factory OcrMatchResult.fromJson(Object? value, {int limit = 5}) {
    Never bad() => throw const OcrFailure(OcrFailureKind.badResponse);
    Map<String, dynamic> object(Object? v, Set<String> keys) {
      if (v is! Map<String, dynamic> ||
          v.length != keys.length ||
          !v.keys.toSet().containsAll(keys)) {
        bad();
      }
      return v;
    }

    int id(Object? v) {
      if (v is! int || v < 1 || v > 9223372036854775807) bad();
      return v;
    }

    String? nullable(Object? v) {
      if (v != null && v is! String) bad();
      return v as String?;
    }

    final json = object(value,
        {'status', 'items', 'preselected_id', 'suggested_query', 'reasons'});
    final status = switch (json['status']) {
      'matched' => OcrMatchStatus.matched,
      'low_confidence' => OcrMatchStatus.lowConfidence,
      'no_match' => OcrMatchStatus.noMatch,
      _ => bad(),
    };
    final list = json['items'], reasons = json['reasons'];
    if (limit < 1 ||
        limit > 10 ||
        list is! List ||
        list.length > limit ||
        reasons is! List) {
      bad();
    }
    final items = <OcrCandidate>[];
    for (final value in list) {
      final c = object(value, {
        'id',
        'name',
        'active_ingredient',
        'strength_text',
        'dosage_form',
        'has_active_ingredients',
        'score'
      });
      final score = c['score'];
      if (c['name'] is! String ||
          c['has_active_ingredients'] is! bool ||
          score is! num ||
          !score.isFinite ||
          score < 0 ||
          score > 1) {
        bad();
      }
      items.add(OcrCandidate(
          id: id(c['id']),
          name: c['name'] as String,
          activeIngredient: nullable(c['active_ingredient']),
          strengthText: nullable(c['strength_text']),
          dosageForm: nullable(c['dosage_form']),
          hasActiveIngredients: c['has_active_ingredients'] as bool,
          score: score.toDouble()));
    }
    if (reasons.any((v) => v is! String || !reasonValues.contains(v)) ||
        reasons.toSet().length != reasons.length) {
      bad();
    }
    final preselected =
        json['preselected_id'] == null ? null : id(json['preselected_id']);
    final query = nullable(json['suggested_query']);
    if (query != null && (query.isEmpty || query.runes.length > 100)) bad();
    if (status == OcrMatchStatus.noMatch ? items.isNotEmpty : items.isEmpty) {
      bad();
    }
    if (status == OcrMatchStatus.matched) {
      if (preselected != items.first.id || query != null) bad();
    } else if (preselected != null) {
      bad();
    }
    return OcrMatchResult(
        status: status,
        items: items,
        preselectedId: preselected,
        suggestedQuery: query,
        reasons: reasons.cast<String>());
  }
}

void validateOcrText(String text, int limit) {
  if (text.trim().isEmpty) throw const OcrFailure(OcrFailureKind.noText);
  if (text.runes.length > 2000) {
    throw const OcrFailure(OcrFailureKind.textTooLong);
  }
  if (limit < 1 || limit > 10) {
    throw const OcrFailure(OcrFailureKind.validation);
  }
}
