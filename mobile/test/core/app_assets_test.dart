import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mọi ảnh trong AppAssets đều được khai báo trong pubspec và đọc được', () async {
    for (final path in AppAssets.all) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });
}
