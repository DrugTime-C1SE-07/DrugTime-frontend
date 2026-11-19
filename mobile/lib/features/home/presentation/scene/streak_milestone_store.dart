import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/storage/secure_storage.dart';

/// Ghi nhớ trên máy các mốc chuỗi ngày (7, 30, 100) đã ăn mừng, để mỗi mốc chỉ phát một lần.
abstract class StreakMilestoneStore {
  static const milestones = [100, 30, 7];

  /// `true` nếu mốc [days] chưa từng phát trên máy này (và đánh dấu luôn là đã phát).
  Future<bool> claim(int days);

  /// Mốc cao nhất ≤ [streak], hoặc `null`.
  static int? reached(int streak) {
    for (final m in milestones) {
      if (streak >= m) return m;
    }
    return null;
  }
}

class SecureStreakMilestoneStore implements StreakMilestoneStore {
  SecureStreakMilestoneStore([FlutterSecureStorage? storage])
      : _storage = SecureStorage(storage: storage);
  final SecureStorage _storage;

  @override
  Future<bool> claim(int days) async {
    final key = 'home_streak_milestone_$days';
    try {
      if (await _storage.read(key: key) != null) return false;
      await _storage.write(key: key, value: '1');
      return true;
    } catch (e) {
      // Không đọc/ghi được thì coi như đã phát, để không ăn mừng lặp lại mỗi lần mở app.
      debugPrint('StreakMilestoneStore: $e');
      return false;
    }
  }
}

class MemoryStreakMilestoneStore implements StreakMilestoneStore {
  final shown = <int>{};

  @override
  Future<bool> claim(int days) async => shown.add(days);
}
