// adhoc-20261116-fix-frontend-main-build AC4: so khớp tên tự nhập theo chuẩn Unicode NFC.
import 'package:drugtime_mobile/features/profile/domain/entities/health_setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // "Tôm" dựng sẵn (NFC) và tổ hợp (NFD: o + dấu mũ U+0302).
  const nfc = 'Tôm';
  const nfd = 'Tôm';

  test('tên tự nhập NFC và NFD của cùng chữ được coi là trùng', () {
    expect(nfc == nfd, isFalse); // hai chuỗi khác nhau ở mức code unit
    const a = HealthSetupStep<String>(HealthSetupStatus.reported, names: [nfc]);
    const b = HealthSetupStep<String>(HealthSetupStatus.reported, names: [' $nfd ']);
    expect(a.matches(b), isTrue);
    expect(b.matches(a), isTrue);
  });

  test('tên khác nhau hoặc khác trạng thái thì không trùng', () {
    const a = HealthSetupStep<String>(HealthSetupStatus.reported, names: [nfc]);
    const c = HealthSetupStep<String>(HealthSetupStatus.reported, names: ['Cua']);
    const d = HealthSetupStep<String>(HealthSetupStatus.noneKnown);
    expect(a.matches(c), isFalse);
    expect(a.matches(d), isFalse);
  });
}
