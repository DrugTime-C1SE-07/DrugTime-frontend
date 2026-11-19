import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'history_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PB21 family route reads local API and rechecks access',
      (tester) async {
    final fixture = await HistoryFixture.read();
    final harness = HistoryHarness(fixture);
    try {
      await harness.start(tester);
      await waitForHistory(
          tester, () => find.text(fixture.medicationName).evaluate().isNotEmpty,
          step: 'family-history-loaded');
      expect(harness.calls, isNotEmpty);
      expect(harness.calls.last.status, 200);
      expect(harness.calls.last.patient, fixture.patient);
      expect(find.text('Xác nhận'), findsNothing);
      expect(find.text('Sửa'), findsNothing);
      await signalHistoryLoaded();

      if (fixture.scenario == 'revoke') {
        await waitForRevocation();
        // The host mutates real DB consent/link/sharing and verifies commit
        // before signalling. The same fixture bearer is used for the next GET.
        final indicator =
            tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).last);
        final refresh = indicator.onRefresh();
        await tester.pump();
        expect(find.text(fixture.medicationName), findsNothing);
        await refresh;
        await waitForHistory(
            tester,
            () =>
                find.text('Không còn quyền xem lịch sử').evaluate().isNotEmpty,
            step: 'revocation-denied');
        expect(harness.calls.last.status, 403);
        expect(harness.calls.last.patient, fixture.patient);
      } else if (fixture.scenario == 'cross_patient') {
        // Remove the first route so it cannot retain P offstage while Q loads.
        harness.navigator.currentState!.pop();
        await tester.pumpAndSettle();
        harness.openPatient(fixture.otherPatient);
        await waitForHistory(
            tester,
            () =>
                find.text('Không còn quyền xem lịch sử').evaluate().isNotEmpty,
            step: 'other-patient-denied');
        expect(harness.calls.last.status, 403);
        expect(harness.calls.last.patient, fixture.otherPatient);
      }
      if (fixture.scenario != 'linked') {
        expect(find.text(fixture.medicationName, skipOffstage: false),
            findsNothing);
      }
      expect(harness.calls.every((call) => call.method == 'GET'), isTrue);
    } finally {
      await harness.close(tester);
    }
  });
}
