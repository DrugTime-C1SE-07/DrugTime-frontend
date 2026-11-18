import 'package:drugtime_mobile/features/home/presentation/scene/streak_milestone_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mỗi mốc chỉ được nhận một lần trên máy (AC20)', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SecureStreakMilestoneStore();
    expect(await store.claim(7), isTrue);
    expect(await store.claim(7), isFalse);
    // mở lại app: bộ lưu mới đọc cùng dữ liệu trên máy
    expect(await SecureStreakMilestoneStore().claim(7), isFalse);
    expect(await store.claim(30), isTrue);
  });

  test('mốc đã lưu từ trước thì không phát', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'home_streak_milestone_100': '1'});
    expect(await SecureStreakMilestoneStore().claim(100), isFalse);
  });

  test('mốc cao nhất đã đạt', () {
    expect(StreakMilestoneStore.reached(6), isNull);
    expect(StreakMilestoneStore.reached(7), 7);
    expect(StreakMilestoneStore.reached(29), 7);
    expect(StreakMilestoneStore.reached(30), 30);
    expect(StreakMilestoneStore.reached(100), 100);
  });
}
