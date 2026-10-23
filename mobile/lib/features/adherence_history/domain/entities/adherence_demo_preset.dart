/// Fixture scenarios for dependency-injected tests, never a user-facing picker.
enum AdherenceDemoPreset {
  mixed('Hỗn hợp'),
  allTaken('Tất cả đã uống'),
  allLate('Tất cả uống trễ'),
  someMissed('Có bỏ lỡ'),
  allMissed('Tất cả chưa ghi nhận'),
  pendingOnly('Chỉ đang chờ'),
  empty('Không có lịch sử'),
  longList('24 liều / tên dài'),
  loading('Đang tải'),
  networkError('Lỗi mạng');

  const AdherenceDemoPreset(this.label);
  final String label;

  /// Stable reference instant for regression tests; app preview injects its own clock.
  DateTime get clock => DateTime.utc(2026, 10, 22, 7);
}
