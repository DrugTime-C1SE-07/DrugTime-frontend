import 'dart:async';

import 'package:drugtime_mobile/features/home/presentation/scene/living_banner.dart';

/// Áp dụng cho mọi test: banner trang chủ vẽ khung tĩnh, không chạy ticker vô hạn,
/// để `pumpAndSettle` không bị treo. Test nào cần hoạt họa tự bật lại `autoplay`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LivingBanner.autoplay = false;
  await testMain();
}
