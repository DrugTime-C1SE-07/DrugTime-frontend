/// Ánh xạ giữa schema của `POST /family/link-requests` (api_contract/openapi.json) và entity
/// của app.
library;

import 'dart:convert';

import '../../../../core/api/api_exception.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/entities/link_request_failure.dart';

abstract final class LinkRequestApiMapper {
  /// `LinkRequestCreate`: đúng hai field (`additionalProperties: false`).
  static Map<String, Object?> createBody({
    required String code,
    required String clientUuid,
  }) =>
      {'client_uuid': clientUuid, 'code': code};

  /// `LinkRequest` (201 và 200).
  static LinkRequest linkRequestFromJson(Map<String, dynamic> json) => LinkRequest(
        id: json['id'] as int,
        status: LinkRequestStatus.fromApi(json['status'] as String?),
        requestedAt: DateTime.parse(json['requested_at'] as String),
      );

  /// Xét mã trạng thái trước, không dựa vào `isTransient`: `ApiClient` coi 429 là lỗi tạm thời,
  /// nhưng ở đây 429 là bị giới hạn và không được tự gửi lại.
  static LinkRequestFailure failureFrom(ApiException error) {
    final status = error.statusCode;
    if (status == null || status == 408 || status >= 500) {
      return const LinkRequestFailure(LinkRequestFailureKind.network);
    }
    final detail = _detail(error.message);
    final kind = switch ((status, detail)) {
      (401, _) => LinkRequestFailureKind.unauthorized,
      (404, 'link_code_not_found') => LinkRequestFailureKind.codeNotFound,
      (409, 'link_request_pending') => LinkRequestFailureKind.alreadyPending,
      (409, 'already_linked') => LinkRequestFailureKind.alreadyLinked,
      (422, 'self_link_not_allowed') => LinkRequestFailureKind.selfLink,
      (422, _ValidationError()) => LinkRequestFailureKind.invalidFormat,
      (429, 'link_request_locked') => LinkRequestFailureKind.locked,
      (429, 'link_request_daily_limit') => LinkRequestFailureKind.dailyLimit,
      (429, 'link_request_cooldown') => LinkRequestFailureKind.cooldown,
      _ => LinkRequestFailureKind.unknown,
    };
    return LinkRequestFailure(
      kind,
      retryAfter: kind.isRateLimited ? error.retryAfter : null,
    );
  }

  /// `detail` dạng chuỗi mã, hoặc [_ValidationError] khi `detail` là mảng lỗi field; `null` khi
  /// body không phải JSON đúng định dạng.
  static Object? _detail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (detail is List) return const _ValidationError();
    } on FormatException {
      return null;
    }
    return null;
  }
}

class _ValidationError {
  const _ValidationError();
}
