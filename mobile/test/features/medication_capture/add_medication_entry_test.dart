import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/scan_medication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// adhoc-20261116 AC15, AC16: every "Thêm thuốc" opens the one scan screen, and the
/// old capture flow and the drug selection demo no longer have routes.
void main() {
  for (final name in [AppRoutes.addMedication, AppRoutes.scanMedication]) {
    testWidgets('$name opens the scan screen (AC16)', (tester) async {
      final route =
          onGenerateRoute(RouteSettings(name: name)) as MaterialPageRoute?;
      expect(route, isNotNull);
      Widget? page;
      await tester.pumpWidget(Builder(builder: (context) {
        page = route!.builder(context);
        return const SizedBox();
      }));
      expect(page, isA<ScanMedicationScreen>());
    });
  }

  test('old capture and demo routes are gone (AC15)', () {
    for (final name in [
      '/medications/capture',
      '/medications/selection-demo'
    ]) {
      expect(onGenerateRoute(RouteSettings(name: name)), isNull, reason: name);
    }
  });
}
