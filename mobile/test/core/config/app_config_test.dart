import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/config/app_config.dart';

void main() {
  test('preview requires both debug build and request', () {
    for (final debug in [false, true]) {
      for (final requested in [false, true]) {
        expect(AppConfig.previewFor(debug: debug, requested: requested),
            debug && requested);
      }
    }
    // Release/profile stay real even if the old flag or PROFILE_PREVIEW is set.
    expect(AppConfig.previewFor(debug: false, requested: true), false);
    expect(AppConfig.previewEnabled, AppConfig.previewRequested);
  });
}
