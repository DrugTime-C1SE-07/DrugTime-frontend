/// Điều khoản dịch vụ và Chính sách quyền riêng tư, phiên bản `termsDocumentVersion`.
///
/// Câu chữ viết theo đúng những gì hệ thống đang làm. Hệ thống hoặc thông tin pháp lý đổi thì
/// sửa văn bản và tăng `termsDocumentVersion` (app) cùng `CURRENT_DOCUMENT_VERSION[TERMS]`
/// (backend): người dùng đã đồng ý bản cũ sẽ được hỏi lại.
library;

import '../../domain/entities/consent.dart';

class LegalSection {
  const LegalSection(this.heading, this.paragraphs);

  final String heading;

  /// Mỗi phần tử là một đoạn; đoạn bắt đầu bằng `- ` hiển thị thành gạch đầu dòng.
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.sections,
    this.intro,
  });

  final String title;
  final String? intro;
  final List<LegalSection> sections;

  String get version => termsDocumentVersion;
  String get effectiveDate => legalEffectiveDate;
}

const legalEffectiveDate = '01/10/2026';
const legalContactEmail = 'drugtime@gmail.com';

const termsOfService = LegalDocument(
  title: 'Điều khoản dịch vụ',
  sections: [
    LegalSection('1. DrugTime là gì', [
      'DrugTime là ứng dụng giúp bạn ghi lại thuốc đang dùng, nhắc giờ uống, theo dõi việc uống '
          'thuốc, cảnh báo tương tác thuốc và (nếu bạn cho phép) chia sẻ tình hình dùng thuốc với '
          'người thân. DrugTime do nhóm phát triển DrugTime cung cấp.',
    ]),
    LegalSection('2. DrugTime không thay thế bác sĩ hay dược sĩ', [
      '- DrugTime không chẩn đoán bệnh, không kê đơn và không thay cho lời khuyên của bác sĩ hay '
          'dược sĩ.',
      '- Cảnh báo tương tác thuốc dựa trên danh mục thuốc và quy tắc có sẵn trong hệ thống. Kết '
          'quả có ba loại: "có tương tác", "đã kiểm tra, chưa thấy tương tác" và "chưa đủ dữ liệu '
          'để kiểm tra". "Chưa thấy tương tác" không có nghĩa là chắc chắn an toàn.',
      '- Gợi ý bữa ăn (nếu bạn bật) chỉ để tham khảo.',
      '- Đừng tự ý bắt đầu, ngừng hay đổi liều thuốc chỉ vì nội dung trong ứng dụng. Hãy hỏi bác '
          'sĩ hoặc dược sĩ.',
      '- Gặp tình huống khẩn cấp, hãy gọi 115 hoặc đến cơ sở y tế gần nhất. DrugTime không phải '
          'dịch vụ cấp cứu.',
    ]),
    LegalSection('3. Tài khoản', [
      '- Bạn đăng nhập bằng số điện thoại hoặc email và mã OTP. Lần đầu đăng nhập, hệ thống sẽ '
          'tạo tài khoản cho bạn.',
      '- Bạn cần từ đủ 16 tuổi để tự tạo tài khoản. DrugTime hiện chỉ dành cho người từ đủ 16 '
          'tuổi. Việc người dưới 16 tuổi sử dụng với sự đồng ý của cha mẹ hoặc người giám hộ sẽ '
          'được bổ sung ở phiên bản sau.',
      '- Không chia sẻ mã OTP cho người khác. Bạn chịu trách nhiệm về các hoạt động diễn ra trên '
          'tài khoản của mình.',
      '- Thông tin bạn nhập (tên thuốc, liều, giờ uống) cần đúng sự thật. Nhắc nhở và cảnh báo '
          'chỉ đúng khi thông tin đầu vào đúng.',
    ]),
    LegalSection('4. Nhắc nhở và thông báo', [
      'Nhắc giờ uống thuốc được gửi qua thông báo đẩy và phụ thuộc vào điện thoại, mạng và cài đặt '
          'thông báo của bạn. DrugTime cố gắng gửi đúng giờ nhưng không bảo đảm mọi thông báo đều '
          'đến. Đừng dùng DrugTime làm cách nhắc duy nhất cho những thuốc mà quên một liều cũng '
          'nguy hiểm.',
    ]),
    LegalSection('5. Người thân', [
      '- Người thân chỉ xem được dữ liệu của bạn khi bạn đã liên kết với họ và bật chia sẻ.',
      '- Bạn có thể tắt chia sẻ hoặc hủy liên kết bất cứ lúc nào. Người thân mất quyền xem ngay '
          'sau đó.',
      '- Khi xem dữ liệu của người khác với tư cách người thân, bạn chỉ được dùng thông tin đó để '
          'chăm sóc họ.',
    ]),
    LegalSection('6. Việc không được làm', [
      'Không truy cập dữ liệu của người khác khi không được cho phép; không can thiệp, dò lỗi hay '
          'làm quá tải hệ thống; không dùng DrugTime vào việc trái pháp luật.',
    ]),
    LegalSection('7. Ngừng sử dụng và xóa tài khoản', [
      'Bạn có thể ngừng dùng bất cứ lúc nào và gửi yêu cầu xóa dữ liệu qua email '
          '$legalContactEmail. Cách xử lý yêu cầu xóa được nêu ở mục 6 của Chính sách quyền riêng '
          'tư. DrugTime có thể khóa tài khoản vi phạm mục 6.',
    ]),
    LegalSection('8. Giới hạn trách nhiệm', [
      'Trong phạm vi pháp luật cho phép, DrugTime không chịu trách nhiệm cho thiệt hại phát sinh '
          'do dùng thông tin trong ứng dụng thay cho tư vấn y tế, do bạn nhập sai thông tin, hoặc '
          'do thông báo không đến vì lý do ngoài tầm kiểm soát của DrugTime.',
    ]),
    LegalSection('9. Thay đổi điều khoản', [
      'Khi điều khoản thay đổi, phiên bản mới sẽ được hiển thị trong ứng dụng. Bạn cần đồng ý lại '
          'thì mới tiếp tục sử dụng được.',
    ]),
    LegalSection('10. Liên hệ', [
      'Email: $legalContactEmail',
    ]),
  ],
);

const privacyPolicy = LegalDocument(
  title: 'Chính sách quyền riêng tư',
  intro: 'Chính sách này giải thích DrugTime thu thập dữ liệu gì, dùng vào việc gì, chia sẻ với ai '
      'và bạn có những quyền gì. Một phần dữ liệu DrugTime xử lý là dữ liệu sức khỏe, thuộc loại '
      'dữ liệu cá nhân nhạy cảm theo pháp luật Việt Nam.',
  sections: [
    LegalSection('1. Dữ liệu được thu thập', [
      '- Định danh: số điện thoại hoặc email, khi đăng nhập.',
      '- Hồ sơ: họ tên, ngày sinh, giới tính, khi bạn hoàn tất hồ sơ.',
      '- Sức khỏe: thuốc đang dùng, liều, giờ uống, lịch sử uống/bỏ lỡ, tình trạng bệnh, đơn thuốc '
          'bạn nhập, khi bạn dùng tính năng quản lý thuốc.',
      '- Liên kết người thân: ai liên kết với ai, trạng thái chia sẻ, khi bạn liên kết người thân.',
      '- Thiết bị: mã thiết bị dùng để gửi thông báo đẩy, khi bạn cho phép thông báo.',
      '- Nhật ký truy cập: ai đã xem dữ liệu sức khỏe của bạn, lúc nào, được phép hay bị từ chối, '
          'mỗi lần dữ liệu sức khỏe được truy cập.',
      '- Lựa chọn đồng ý: bạn đã đồng ý hay rút đồng ý mục đích nào, phiên bản văn bản, thời điểm, '
          'khi bạn đồng ý hoặc rút đồng ý.',
      'DrugTime không thu thập danh bạ, vị trí hay hình ảnh của bạn, trừ khi một tính năng cụ thể '
          'hỏi bạn trước.',
    ]),
    LegalSection('2. Dùng dữ liệu vào việc gì', [
      'Mỗi mục đích có lựa chọn đồng ý riêng, và bạn quản lý chúng trong Cài đặt › Quyền riêng tư:',
      '- Dữ liệu sức khỏe (bắt buộc để dùng tính năng chính): nhắc giờ uống, ghi nhận liều, theo '
          'dõi việc dùng thuốc, cảnh báo tương tác.',
      '- Chia sẻ với người thân (tùy chọn): người thân đã liên kết xem tình hình dùng thuốc và nhận '
          'cảnh báo khi bạn bỏ liều.',
      '- Gợi ý bữa ăn bằng AI (tùy chọn): dùng danh sách thuốc của bạn để gợi ý bữa ăn.',
      'Ngoài ra, dữ liệu định danh còn được dùng để đăng nhập, và nhật ký truy cập dùng để bảo vệ '
          'tài khoản của bạn.',
      'DrugTime không bán dữ liệu của bạn và không dùng dữ liệu sức khỏe cho quảng cáo.',
    ]),
    LegalSection('3. Chia sẻ với ai', [
      '- Người thân: chỉ khi bạn đã liên kết và bật chia sẻ (mục 2).',
      '- Nhà cung cấp hạ tầng xử lý dữ liệu thay cho DrugTime: Supabase (cơ sở dữ liệu và xác '
          'thực; dữ liệu được lưu trên máy chủ của nhà cung cấp đặt ở nước ngoài); Firebase Cloud '
          'Messaging của Google (gửi thông báo đẩy); nhà cung cấp dịch vụ gửi tin nhắn SMS chứa mã '
          'OTP.',
      '- Cơ quan nhà nước có thẩm quyền: khi pháp luật yêu cầu.',
      'Các nhà cung cấp trên đặt máy chủ ở nước ngoài, nên dữ liệu của bạn được lưu trữ và xử lý '
          'ngoài lãnh thổ Việt Nam.',
    ]),
    LegalSection('4. Bảo vệ dữ liệu', [
      '- Dữ liệu được truyền qua kết nối mã hóa (HTTPS).',
      '- Mỗi lần có người xem dữ liệu sức khỏe, hệ thống kiểm tra quyền và ghi nhật ký. Nhật ký '
          'này không ai sửa hay xóa được.',
      '- Rút đồng ý hoặc tắt chia sẻ có hiệu lực ngay ở lần truy cập kế tiếp.',
      '- Không có hệ thống nào an toàn tuyệt đối. Nếu xảy ra sự cố lộ dữ liệu, DrugTime sẽ thông '
          'báo theo quy định.',
    ]),
    LegalSection('5. Lưu giữ trong bao lâu', [
      'Dữ liệu được giữ trong thời gian bạn còn dùng tài khoản. Khi yêu cầu xóa được xử lý xong, '
          'thông tin định danh và hồ sơ của bạn bị xóa. Riêng nhật ký truy cập và bản ghi đồng ý '
          'được giữ thêm trong thời hạn pháp luật yêu cầu để làm bằng chứng tuân thủ.',
    ]),
    LegalSection('6. Quyền của bạn', [
      '- Xem dữ liệu của mình trong ứng dụng.',
      '- Sửa thông tin hồ sơ và thuốc.',
      '- Rút đồng ý từng mục đích trong Cài đặt › Quyền riêng tư. Rút đồng ý không làm mất hiệu '
          'lực các việc đã làm trước đó.',
      '- Gửi yêu cầu xóa dữ liệu qua email $legalContactEmail. Bạn sẽ được báo kết quả.',
      '- Khiếu nại qua $legalContactEmail.',
    ]),
    LegalSection('7. Trẻ em', [
      'DrugTime hiện chỉ dành cho người từ đủ 16 tuổi. Việc người dưới 16 tuổi sử dụng với sự đồng '
          'ý của cha mẹ hoặc người giám hộ sẽ được bổ sung ở phiên bản sau.',
    ]),
    LegalSection('8. Thay đổi chính sách', [
      'Khi chính sách thay đổi, phiên bản mới sẽ được hiển thị trong ứng dụng, và bạn sẽ được hỏi '
          'lại nếu thay đổi đó ảnh hưởng tới dữ liệu của bạn.',
    ]),
    LegalSection('9. Liên hệ', [
      'Đơn vị chịu trách nhiệm xử lý dữ liệu: nhóm phát triển DrugTime. Liên hệ về quyền riêng tư: '
          '$legalContactEmail.',
    ]),
  ],
);
