import 'package:share_plus/share_plus.dart';

/// Mở bảng chia sẻ của hệ thống (Zalo, SMS, Email…); tách ra để test thay bằng bản giả.
abstract interface class InviteLinkSharer {
  Future<void> share(String text);
}

class SystemInviteLinkSharer implements InviteLinkSharer {
  const SystemInviteLinkSharer();

  @override
  Future<void> share(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
