/// Ánh xạ giữa schema của `/consents` (api_contract/openapi.json) và entity của app.
library;

import 'dart:convert';

import '../../../../core/api/api_exception.dart';
import '../../domain/entities/consent.dart';
import '../../domain/entities/consent_failure.dart';

abstract final class ConsentApiMapper {
  /// `Consent` → [ConsentState].
  static ConsentState consentFromJson(Map<String, dynamic> json) {
    final grantedAt = json['granted_at'] as String?;
    return ConsentState(
      purpose: ConsentPurpose.fromApi(json['purpose'] as String),
      granted: json['status'] == 'granted',
      grantedAt: grantedAt == null ? null : DateTime.parse(grantedAt),
      documentVersion: json['document_version'] as String?,
      currentDocumentVersion: json['current_document_version'] as String,
    );
  }

  /// `ConsentList` → danh sách theo thứ tự server trả.
  static List<ConsentState> consentListFromJson(Object? json) {
    final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
    return items.map(consentFromJson).toList(growable: false);
  }

  static Map<String, Object?> grantBody(ConsentPurpose purpose) => {
        'purpose': purpose.apiValue,
        'document_version': consentDocumentVersion,
      };

  static ConsentFailure failureFrom(ApiException error) {
    final status = error.statusCode;
    if (status == null || error.isTransient) {
      return ConsentFailure(ConsentFailureKind.network, error.message);
    }
    final kind = switch ((status, _detail(error.message))) {
      (401, _) => ConsentFailureKind.unauthorized,
      (422, 'consent_document_outdated') => ConsentFailureKind.documentOutdated,
      _ => ConsentFailureKind.unknown,
    };
    return ConsentFailure(kind, error.message);
  }

  /// `detail` dạng chuỗi mã; `null` khi body không phải JSON hoặc `detail` là mảng lỗi field.
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
