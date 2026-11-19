import '../state/link_request_controller.dart';

/// Câu chung cho 404: server cố ý không phân biệt mã sai với patient chưa bật chia sẻ (BS-05),
/// nên app cũng không được phân biệt.
const linkCodeNotFoundMessage =
    'Mã không đúng, hoặc người thân chưa bật chia sẻ với gia đình.';

const invalidQrMessage = 'Đây không phải mã liên kết DrugTime.';
const invalidInviteLinkMessage = 'Link mời không hợp lệ.';

/// Câu thông báo cho [error]. Lỗi 429 kèm thời gian còn lại khi biết [remaining].
String linkSubmitErrorMessage(LinkSubmitError error, {Duration? remaining}) {
  final wait = remaining == null ? '' : ' Thử lại sau ${formatRetryAfter(remaining)}.';
  return switch (error) {
    LinkSubmitError.codeNotFound => linkCodeNotFoundMessage,
    LinkSubmitError.selfLink => 'Đây là mã của chính bạn.',
    LinkSubmitError.invalidFormat => 'Mã không đúng định dạng.',
    LinkSubmitError.alreadyLinked => 'Bạn đã theo dõi người này rồi.',
    LinkSubmitError.locked => 'Bạn đã nhập sai mã nhiều lần.$wait',
    LinkSubmitError.dailyLimit => 'Bạn đã gửi đủ số yêu cầu trong ngày.$wait',
    LinkSubmitError.cooldown => 'Người này đã từ chối nhiều lần liên tiếp.$wait',
    LinkSubmitError.network => 'Không kết nối được, thử lại.',
    LinkSubmitError.unknown => 'Đã có lỗi xảy ra, thử lại.',
    LinkSubmitError.requestClosed =>
      'Yêu cầu này không còn hiệu lực. Bạn có thể gửi lại.',
  };
}

/// Dưới 1 giờ: `m:ss`. Từ 1 giờ: `H giờ MM phút`, làm tròn phút lên để không báo thiếu.
String formatRetryAfter(Duration wait) {
  if (wait < const Duration(hours: 1)) {
    final minutes = wait.inMinutes;
    final seconds = wait.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  final totalMinutes = (wait.inSeconds + 59) ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '$hours giờ ${minutes.toString().padLeft(2, '0')} phút';
}

/// Lỗi định dạng hiện ngay dưới ô nhập; `null` khi ô trống hoặc mã hợp lệ.
String? linkCodeFormatError(String normalized, {required bool valid}) {
  if (normalized.isEmpty || valid) return null;
  if (RegExp(r'[^A-HJKMNP-Z2-9]').hasMatch(normalized)) {
    return 'Mã chỉ gồm chữ và số, không có 0, O, 1, I, L.';
  }
  if (normalized.length < 10) {
    return 'Mã cần đủ 10 ký tự (còn thiếu ${10 - normalized.length}).';
  }
  return 'Mã không đúng định dạng.';
}
