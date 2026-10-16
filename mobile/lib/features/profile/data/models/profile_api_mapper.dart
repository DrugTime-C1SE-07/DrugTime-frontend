import 'dart:convert';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/condition.dart';
import '../../domain/entities/health_profile.dart';
import '../../domain/entities/profile_failure.dart';

abstract final class ProfileApiMapper {
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile shape');
    }
    return value;
  }

  static int id(Object? value) {
    if (value is! int || value <= 0) {
      throw const FormatException('Invalid profile id');
    }
    return value;
  }

  static String? gender(String? value) => switch (value) {
        'nam' || 'male' => 'nam',
        'nu' || 'female' => 'nu',
        _ => null,
      };
  static String dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static DateTime? parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      throw const FormatException('Invalid calendar date');
    }
    final date = DateTime.parse(raw);
    if (dateString(date) != raw) {
      throw const FormatException('Invalid calendar date');
    }
    return date;
  }

  static ProfileCondition condition(Object? value) {
    final j = object(value);
    return ProfileCondition(
        id: id(j['id']),
        conditionId: id(j['condition_id']),
        name: j['condition_name'] as String,
        subtype: j['subtype'] as String?,
        stage: j['stage'] as String?);
  }

  static HealthProfile profile(Object? value) {
    final j = object(value);
    return HealthProfile(
        fullName: j['full_name'] as String?,
        dateOfBirth: parseDate(j['date_of_birth']),
        gender: gender(j['gender'] as String?),
        conditions:
            List.unmodifiable((j['conditions'] as List).map(condition)));
  }

  static Map<String, Object?> updateBody(ProfileDraft draft) => {
        'full_name': draft.fullName.trim(),
        'date_of_birth': dateString(draft.dateOfBirth),
        'gender': draft.gender,
      };
  static Map<String, String?> metadataChanges(ProfileCondition before,
          {required String? subtype, required String? stage}) =>
      {
        if (before.subtype != subtype) 'subtype': subtype,
        if (before.stage != stage) 'stage': stage,
      };
  static ConditionPage page(Object? value) {
    final j = object(value);
    return ConditionPage(
        items: List.unmodifiable((j['items'] as List).map((e) {
          final item = object(e);
          return ConditionItem(id(item['id']), item['name'] as String);
        })),
        total: j['total'] as int,
        offset: j['offset'] as int);
  }

  static ProfileFailure failure(ApiException error) {
    String? code;
    try {
      final parsed = jsonDecode(error.message);
      if (parsed is Map && parsed['detail'] is String) {
        code = parsed['detail'] as String;
      }
    } on FormatException {
      // Non-JSON errors are mapped by HTTP status; never display raw response bodies.
    }
    return ProfileFailure(switch (error.statusCode) {
      401 => ProfileFailureKind.unauthorized,
      403 => code == 'consent_revoked' || code == 'health_data_consent_required'
          ? ProfileFailureKind.consent
          : ProfileFailureKind.forbidden,
      404 => ProfileFailureKind.missing,
      409 => ProfileFailureKind.duplicate,
      422 => ProfileFailureKind.validation,
      null => ProfileFailureKind.network,
      _ => ProfileFailureKind.unavailable,
    });
  }
}
