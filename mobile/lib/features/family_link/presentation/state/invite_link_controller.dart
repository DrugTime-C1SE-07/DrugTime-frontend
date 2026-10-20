import 'package:flutter/foundation.dart';

/// Link mời đã đọc, đang chờ mở màn nhập mã. [code] là `null` khi link không hợp lệ.
typedef PendingInvite = ({String? code});

/// Giữ link mời trong bộ nhớ cho tới khi `AppShell` (chỉ dựng sau khi đăng nhập xong) lấy ra.
/// Nhờ vậy người chưa đăng nhập đi hết luồng đăng nhập rồi vẫn tới đúng màn nhập mã.
class InviteLinkController extends ChangeNotifier {
  PendingInvite? _pending;

  bool get hasPending => _pending != null;

  /// Link mới thay link cũ chưa xử lý.
  void offer({required String? code}) {
    _pending = (code: code);
    notifyListeners();
  }

  /// Lấy link đang chờ và xóa nó, để chỉ mở màn nhập mã một lần.
  PendingInvite? take() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  /// Đăng xuất: bỏ link của phiên trước.
  void clear() => _pending = null;
}
