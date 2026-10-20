import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/storage/local_db/client_uuid.dart';
import '../../domain/entities/link_code.dart';
import '../../domain/entities/link_request.dart';
import '../../domain/entities/link_request_failure.dart';
import '../../domain/repositories/family_link_repository.dart';

/// Lỗi hiển thị trên màn nhập mã.
enum LinkSubmitError {
  codeNotFound,
  selfLink,
  invalidFormat,
  alreadyLinked,
  locked,
  dailyLimit,
  cooldown,
  network,
  unknown,

  /// Gửi lại (200) nhận yêu cầu đã bị từ chối hoặc hủy: yêu cầu đó không còn hiệu lực.
  requestClosed;

  bool get isRateLimited => this == locked || this == dailyLimit || this == cooldown;

  /// Lỗi tạm thời: "Thử lại" gửi lại đúng `client_uuid` cũ.
  bool get isRetryable => this == network || this == unknown;
}

/// Kết quả thành công: màn nhập mã chuyển sang màn kết quả.
enum LinkSubmitOutcome {
  /// Đang chờ patient chấp thuận (gồm 409 `link_request_pending` và `status` chưa biết).
  waiting,

  /// Gửi lại nhận `active`: patient đã chấp thuận.
  accepted,
}

/// Trạng thái gửi yêu cầu liên kết của một màn nhập mã.
///
/// Quy tắc `client_uuid` (contract 3.13): sinh mới cho mỗi lần gửi mới; giữ nguyên khi gửi lại
/// sau lỗi mạng hay lỗi không xác định để server không tạo yêu cầu thứ hai; bỏ khi mã đổi hoặc
/// khi server đã trả lời dứt khoát. Chỉ giữ trong bộ nhớ.
class LinkRequestController extends ChangeNotifier {
  LinkRequestController(
    this._repository, {
    required String inviteLinkHost,
    String Function()? uuidFactory,
  })  : _host = inviteLinkHost,
        _uuidFactory = uuidFactory ?? createClientUuid;

  final FamilyLinkRepository _repository;
  final String _host;
  final String Function() _uuidFactory;

  String _input = '';
  String? _clientUuid;
  bool _sending = false;
  LinkSubmitError? _error;
  LinkSubmitOutcome? _outcome;
  Duration? _remaining;
  Timer? _ticker;
  bool _disposed = false;

  /// Mã đã chuẩn hóa, hoặc `null` khi chưa hợp lệ.
  String? get code => extractLinkCode(_input, host: _host);

  /// Phần đã gõ sau khi chuẩn hóa (chưa chắc hợp lệ).
  String get normalizedInput => normalizeLinkCodeInput(_input);

  bool get isSending => _sending;
  LinkSubmitError? get error => _error;
  LinkSubmitOutcome? get outcome => _outcome;

  /// Thời gian còn phải chờ sau 429; `null` khi không bị giới hạn hoặc server không nói.
  Duration? get remaining => _remaining;

  bool get canSubmit => !_sending && _remaining == null && code != null;

  /// Người dùng sửa ô nhập. Mã đổi thì lần gửi sau là một lần gửi mới.
  ///
  /// Khóa `locked`/`dailyLimit` áp lên người gửi với mọi mã, nên vẫn giữ câu báo và đếm ngược;
  /// `cooldown` chỉ áp cho patient của mã cũ, nên bỏ khi mã đổi.
  void updateInput(String raw) {
    final before = code;
    _input = raw;
    if (code != before) {
      _clientUuid = null;
      if (_error == LinkSubmitError.cooldown) _stopCountdown();
      if (_remaining == null) _error = null;
    }
    notifyListeners();
  }

  /// Gửi yêu cầu, hoặc gửi lại sau lỗi tạm thời. Không làm gì khi đang gửi, đang bị giới hạn
  /// hay mã chưa hợp lệ.
  Future<void> submit() async {
    final code = this.code;
    if (!canSubmit || code == null) return;
    final clientUuid = _clientUuid ??= _uuidFactory();
    _sending = true;
    _error = null;
    _notify();
    try {
      final request = await _repository.sendLinkRequest(code: code, clientUuid: clientUuid);
      _applyStatus(request.status);
    } on LinkRequestFailure catch (failure) {
      _applyFailure(failure);
    } finally {
      _sending = false;
      _notify();
    }
  }

  void _applyStatus(LinkRequestStatus status) {
    switch (status) {
      case LinkRequestStatus.pending || LinkRequestStatus.unknown:
        _outcome = LinkSubmitOutcome.waiting;
      case LinkRequestStatus.active:
        _outcome = LinkSubmitOutcome.accepted;
      case LinkRequestStatus.rejected || LinkRequestStatus.revoked:
        _clientUuid = null;
        _error = LinkSubmitError.requestClosed;
    }
  }

  void _applyFailure(LinkRequestFailure failure) {
    final error = switch (failure.kind) {
      LinkRequestFailureKind.alreadyPending => null,
      // ApiClient đã đưa người dùng về màn Đăng nhập; không báo lỗi về mã.
      LinkRequestFailureKind.unauthorized => null,
      LinkRequestFailureKind.codeNotFound => LinkSubmitError.codeNotFound,
      LinkRequestFailureKind.selfLink => LinkSubmitError.selfLink,
      LinkRequestFailureKind.invalidFormat => LinkSubmitError.invalidFormat,
      LinkRequestFailureKind.alreadyLinked => LinkSubmitError.alreadyLinked,
      LinkRequestFailureKind.locked => LinkSubmitError.locked,
      LinkRequestFailureKind.dailyLimit => LinkSubmitError.dailyLimit,
      LinkRequestFailureKind.cooldown => LinkSubmitError.cooldown,
      LinkRequestFailureKind.network => LinkSubmitError.network,
      LinkRequestFailureKind.unknown => LinkSubmitError.unknown,
    };
    if (failure.kind == LinkRequestFailureKind.alreadyPending) {
      _outcome = LinkSubmitOutcome.waiting;
      return;
    }
    // Server đã trả lời dứt khoát (4xx): lần gửi sau là lần gửi mới.
    if (error == null || !error.isRetryable) _clientUuid = null;
    _error = error;
    if (failure.retryAfter case final wait? when error != null && error.isRateLimited) {
      _startCountdown(wait);
    }
  }

  // Dùng Timer thay cho so đồng hồ, để widget test tua thời gian được.
  void _startCountdown(Duration wait) {
    _ticker?.cancel();
    _remaining = wait;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _remaining! - const Duration(seconds: 1);
      if (next > Duration.zero) {
        _remaining = next;
      } else {
        _stopCountdown();
      }
      _notify();
    });
  }

  void _stopCountdown() {
    _ticker?.cancel();
    _ticker = null;
    _remaining = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
