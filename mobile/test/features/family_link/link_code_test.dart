import 'package:drugtime_mobile/features/family_link/domain/entities/link_code.dart';
import 'package:flutter_test/flutter_test.dart';

const _host = 'drug-time-frontend.vercel.app';

void main() {
  group('linkCodeFromQrPayload', () {
    test('AC1: drugtime://link?code=<mã> → mã', () {
      expect(linkCodeFromQrPayload('drugtime://link?code=K7M2Q9XAR4'), 'K7M2Q9XAR4');
    });

    test('AC2: mọi chuỗi khác định dạng contract 3.10 → null', () {
      const invalid = [
        'https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR4',
        'K7M2Q9XAR4',
        'xin chào',
        '',
        'otherapp://link?code=K7M2Q9XAR4',
        'drugtime://invite?code=K7M2Q9XAR4',
        'drugtime://link/x?code=K7M2Q9XAR4',
        'drugtime://link',
        'drugtime://link?ma=K7M2Q9XAR4',
        'drugtime://link?code=K7M2Q9XAR0', // có 0
        'drugtime://link?code=K7M2Q9XAO4', // có O
        'drugtime://link?code=K7M2Q9XAI4', // có I
        'drugtime://link?code=K7M2Q9XAL4', // có L
        'drugtime://link?code=K7M2Q9XA14', // có 1
        'drugtime://link?code=k7m2q9xar4', // chữ thường
        'drugtime://link?code=K7M2Q9XAR', // 9 ký tự
        'drugtime://link?code=K7M2Q9XAR44', // 11 ký tự
        'drugtime://link?code=K7M2Q9XAR4#x',
      ];
      for (final raw in invalid) {
        expect(linkCodeFromQrPayload(raw), isNull, reason: raw);
      }
    });
  });

  group('normalizeLinkCodeInput / extractLinkCode', () {
    test('AC3: chữ thường, khoảng trắng, gạch nối được chuẩn hóa', () {
      expect(normalizeLinkCodeInput('k7m2 q9xa-r4'), 'K7M2Q9XAR4');
      expect(extractLinkCode('  k7m2 q9xa-r4 ', host: _host), 'K7M2Q9XAR4');
    });

    test('AC3: dán chuỗi QR hoặc link mời → tách mã', () {
      expect(extractLinkCode('drugtime://link?code=K7M2Q9XAR4', host: _host), 'K7M2Q9XAR4');
      expect(
        extractLinkCode('https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR4', host: _host),
        'K7M2Q9XAR4',
      );
    });

    test('AC3: 9 ký tự hoặc ký tự ngoài bảng mã → null', () {
      for (final raw in ['K7M2Q9XAR', 'K7M2Q9XA01', 'K7M2Q9XAR4!', 'K7M2Q9XAR4K', '']) {
        expect(extractLinkCode(raw, host: _host), isNull, reason: raw);
      }
      expect(isValidLinkCode('K7M2Q9XAR4'), isTrue);
    });
  });

  test('AC22: inviteLinkFor ghép link mời và đọc ngược ra đúng mã', () {
    final link = inviteLinkFor('K7M2Q9XAR4', host: _host);

    expect(link, 'https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR4');
    expect(linkCodeFromInviteUri(Uri.parse(link), host: _host), 'K7M2Q9XAR4');
  });

  group('linkCodeFromInviteUri', () {
    test('AC15: mã ở fragment #code=', () {
      final uri = Uri.parse('https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR4');
      expect(linkCodeFromInviteUri(uri, host: _host), 'K7M2Q9XAR4');
    });

    test('AC15: mã ở query ?code= (đường "Mở bằng ứng dụng" của landing)', () {
      final uri = Uri.parse('https://drug-time-frontend.vercel.app/link?code=K7M2Q9XAR4');
      expect(linkCodeFromInviteUri(uri, host: _host), 'K7M2Q9XAR4');
    });

    test('AC15: host so không phân biệt hoa thường', () {
      final uri = Uri.parse('https://Drug-Time-Frontend.vercel.app/link#code=K7M2Q9XAR4');
      expect(linkCodeFromInviteUri(uri, host: _host), 'K7M2Q9XAR4');
    });

    test('AC15: sai host, path, scheme, thiếu code, sai pattern → null', () {
      const invalid = [
        'https://evil.example.com/link#code=K7M2Q9XAR4',
        'https://drug-time-frontend.vercel.app/invite#code=K7M2Q9XAR4',
        'https://drug-time-frontend.vercel.app/link/#code=K7M2Q9XAR4',
        'http://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR4',
        'https://drug-time-frontend.vercel.app/link',
        'https://drug-time-frontend.vercel.app/link#ma=K7M2Q9XAR4',
        'https://drug-time-frontend.vercel.app/link#code=k7m2q9xar4',
        'https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR0',
        'https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR',
      ];
      for (final raw in invalid) {
        expect(linkCodeFromInviteUri(Uri.parse(raw), host: _host), isNull, reason: raw);
      }
    });
  });
}
