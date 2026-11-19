/// Ánh xạ giữa schema `/family/links*` và `/family/caregivers` (api_contract/openapi.json) và
/// entity phía patient của app.
library;

import 'dart:convert';

import '../../../../core/api/api_exception.dart';
import '../../domain/entities/caregiver.dart';
import '../../domain/entities/caregiver_failure.dart';
import '../../domain/entities/incoming_link_request.dart';

abstract final class CaregiverApiMapper {
  /// `PendingFamilyLinkList`.
  static List<IncomingLinkRequest> pendingFromJson(Map<String, dynamic> json) => [
        for (final item in json['items'] as List)
          IncomingLinkRequest(
            linkId: (item as Map<String, dynamic>)['link_id'] as int,
            familyUserId: item['family_user_id'] as String,
            familyName: item['family_full_name'] as String?,
            requestedAt: DateTime.parse(item['requested_at'] as String),
            familyPhone: (item['family_phone'] ?? item['phone'] ?? item['phone_number']) as String?,
            familyEmail: (item['family_email'] ?? item['email']) as String?,
          ),
      ];

  /// `FamilyLinkApprovalRequest`: đúng ba field; `consent_confirmed` chỉ nhận `true`.
  static Map<String, Object?> approveBody({
    required String familyUserId,
    required String documentVersion,
  }) =>
      {
        'family_user_id': familyUserId,
        'consent_confirmed': true,
        'document_version': documentVersion,
      };

  /// `FamilyLinkSharingUpdate`.
  static Map<String, Object?> sharingBody(bool enabled) => {'sharing_enabled': enabled};

  /// `CaregiverList`.
  static List<Caregiver> caregiversFromJson(Map<String, dynamic> json) => [
        for (final item in json['items'] as List)
          caregiverFromJson(item as Map<String, dynamic>),
      ];

  /// `Caregiver` (một mục danh sách, và response của PATCH sharing).
  static Caregiver caregiverFromJson(Map<String, dynamic> json) => Caregiver(
        linkId: json['link_id'] as int,
        familyUserId: json['family_user_id'] as String,
        familyName: json['family_full_name'] as String?,
        sharingEnabled: json['sharing_enabled'] as bool,
        approvedAt: switch (json['approved_at']) {
          final String value => DateTime.parse(value),
          _ => null,
        },
      );

  static CaregiverFailure failureFrom(ApiException error) {
    final status = error.statusCode;
    if (status == null || status == 408 || status >= 500) {
      return const CaregiverFailure(CaregiverFailureKind.network);
    }
    final detail = _detail(error.message);
    final kind = switch ((status, detail)) {
      (401, _) => CaregiverFailureKind.unauthorized,
      (403, 'consent_revoked') => CaregiverFailureKind.consentRequired,
      (403, _) => CaregiverFailureKind.forbidden,
      (404, _) => CaregiverFailureKind.notFound,
      (409, 'consent_confirmation_missing') =>
        CaregiverFailureKind.confirmationMissing,
      (409, _) => CaregiverFailureKind.conflict,
      (422, 'consent_document_outdated') =>
        CaregiverFailureKind.documentOutdated,
      (422, _) => CaregiverFailureKind.invalid,
      _ => CaregiverFailureKind.unknown,
    };
    return CaregiverFailure(kind);
  }

  /// `detail` dạng chuỗi mã; `null` khi là mảng lỗi field hoặc body không phải JSON.
  static String? _detail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) return decoded['detail'] as String;
    } on FormatException {
      return null;
    }
    return null;
  }
}
