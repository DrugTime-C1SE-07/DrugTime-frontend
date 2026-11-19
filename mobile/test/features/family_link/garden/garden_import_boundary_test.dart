import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cảnh khu vườn phải có phong cách riêng: không dùng lại banner trang chủ (AC15).
void main() {
  test('garden/** không import features/home/presentation/scene', () {
    final dir = Directory('lib/features/family_link/presentation/garden');
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    final banned = RegExp(r'''import\s+['"][^'"]*home/presentation/scene/''');
    for (final file in files) {
      expect(banned.hasMatch(file.readAsStringSync()), isFalse,
          reason: file.path);
    }
  });
}
