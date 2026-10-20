import 'dart:async';

import '../../domain/entities/link_request.dart';
import '../../domain/repositories/family_link_repository.dart';

/// Lời gọi đã nhận, để test kiểm tham số.
typedef SentLinkRequest = ({String code, String clientUuid});

/// Yêu cầu liên kết trong bộ nhớ: bản web xem thử và test.
///
/// Mỗi lần gọi lấy một phản hồi từ [responses] theo thứ tự: `LinkRequest` thì trả về,
/// `LinkRequestFailure` (hay lỗi khác) thì ném, `Completer<LinkRequest>` thì chờ tới khi test
/// hoàn tất nó. Hết hàng đợi thì trả yêu cầu `pending`.
class InMemoryFamilyLinkRepository implements FamilyLinkRepository {
  InMemoryFamilyLinkRepository({List<Object>? responses})
      : responses = responses ?? [];

  final List<Object> responses;
  final List<SentLinkRequest> calls = [];
  int _nextId = 1;

  @override
  Future<LinkRequest> sendLinkRequest({
    required String code,
    required String clientUuid,
  }) async {
    calls.add((code: code, clientUuid: clientUuid));
    if (responses.isEmpty) {
      return LinkRequest(
        id: _nextId++,
        status: LinkRequestStatus.pending,
        requestedAt: DateTime.now(),
      );
    }
    return switch (responses.removeAt(0)) {
      final LinkRequest request => request,
      final Completer<LinkRequest> completer => completer.future,
      final Object error => throw error,
    };
  }
}
