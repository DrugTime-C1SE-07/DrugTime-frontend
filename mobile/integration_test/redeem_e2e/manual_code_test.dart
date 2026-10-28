import 'dart:io';

import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/link_request_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'redeem_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('redeem manual code through production app and remote repository',
      (tester) async {
    final fixture = await RedeemFixture.read();
    try {
      expect(
        {'direct_pending', 'double_tap', 'response_lost', 'unauthorized'},
        contains(fixture.scenario),
        reason: 'Unknown redeem scenario',
      );
      await startRedeemApp(tester, fixture);
      await openManualCode(tester);

      final field = find.byKey(const Key('link-code-field'));
      final submit = find.byKey(const Key('link-code-submit'));
      await tester.enterText(field, fixture.code);
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

      if (fixture.scenario == 'double_tap') {
        // Both taps use the same visible button before the next frame. The
        // controller must suppress the second call while the first is pending.
        await tester.tap(submit);
        await tester.tap(submit);
        await tester.pump();
      } else {
        await tapRedeem(tester, submit);
      }

      if (fixture.scenario == 'response_lost') {
        await waitForRedeem(tester, find.text('Thử lại'),
            step: 'retry-visible');
        await tapRedeem(tester, submit);
      }

      if (fixture.scenario == 'unauthorized') {
        await waitForRedeem(tester, find.byType(LoginMobileScreen),
            step: 'session-expired');
        expect(find.byType(LinkRequestResultScreen), findsNothing);
      } else {
        await waitForRedeem(tester, find.byType(LinkRequestResultScreen),
            step: 'pending-result');
        expect(find.text('Đang chờ xác nhận'), findsOneWidget);
        expect(find.textContaining('Bạn chưa xem được gì'), findsOneWidget);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await clearRedeemSession();
      await File(redeemFixturePath).delete();
    }
  });
}
