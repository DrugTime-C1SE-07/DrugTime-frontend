import 'package:drugtime_mobile/features/family_link/presentation/state/link_request_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/widgets/link_request_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AC6: mỗi lỗi có câu riêng theo bảng của requirement', () {
    expect(linkSubmitErrorMessage(LinkSubmitError.codeNotFound),
        'Mã không đúng, hoặc người thân chưa bật chia sẻ với gia đình.');
    expect(linkSubmitErrorMessage(LinkSubmitError.selfLink), 'Đây là mã của chính bạn.');
    expect(linkSubmitErrorMessage(LinkSubmitError.invalidFormat), 'Mã không đúng định dạng.');
    expect(linkSubmitErrorMessage(LinkSubmitError.alreadyLinked),
        'Bạn đã theo dõi người này rồi.');
    expect(linkSubmitErrorMessage(LinkSubmitError.network), 'Không kết nối được, thử lại.');
    final messages = {for (final e in LinkSubmitError.values) linkSubmitErrorMessage(e)};
    expect(messages, hasLength(LinkSubmitError.values.length));
  });

  test('AC20: lỗi 429 kèm thời gian còn lại khi biết', () {
    expect(
      linkSubmitErrorMessage(LinkSubmitError.locked, remaining: const Duration(seconds: 900)),
      'Bạn đã nhập sai mã nhiều lần. Thử lại sau 15:00.',
    );
    expect(
      linkSubmitErrorMessage(LinkSubmitError.dailyLimit),
      'Bạn đã gửi đủ số yêu cầu trong ngày.',
    );
    expect(
      linkSubmitErrorMessage(LinkSubmitError.cooldown, remaining: const Duration(hours: 24)),
      'Người này đã từ chối nhiều lần liên tiếp. Thử lại sau 24 giờ 00 phút.',
    );
  });

  test('formatRetryAfter', () {
    expect(formatRetryAfter(const Duration(seconds: 59)), '0:59');
    expect(formatRetryAfter(const Duration(seconds: 900)), '15:00');
    expect(formatRetryAfter(const Duration(minutes: 59, seconds: 59)), '59:59');
    expect(formatRetryAfter(const Duration(hours: 3, minutes: 5)), '3 giờ 05 phút');
    expect(formatRetryAfter(const Duration(hours: 3, minutes: 4, seconds: 30)), '3 giờ 05 phút');
  });

  test('AC3: lỗi định dạng dưới ô nhập', () {
    expect(linkCodeFormatError('', valid: false), isNull);
    expect(linkCodeFormatError('K7M2Q9XAR4', valid: true), isNull);
    expect(linkCodeFormatError('K7M2Q9XAR', valid: false), 'Mã cần đủ 10 ký tự (còn thiếu 1).');
    expect(linkCodeFormatError('K7M2Q9XA0', valid: false),
        'Mã chỉ gồm chữ và số, không có 0, O, 1, I, L.');
  });
}
