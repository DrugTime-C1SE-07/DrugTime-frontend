import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/features/auth/data/sources/auth_session_store.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/link_code.dart';
import 'package:drugtime_mobile/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The test runner writes this private Android file with `adb shell run-as`.
/// It contains a short-lived local session and is never an app asset or dart-define.
const redeemFixturePath =
    '/data/data/vn.drugtime.drugtime_mobile/files/redeem_e2e_fixture.json';

const _step = Duration(milliseconds: 100);
const _timeout = Duration(seconds: 25);

class RedeemFixture {
  const RedeemFixture({
    required this.session,
    required this.code,
    required this.qrPayload,
    required this.scenario,
  });

  final AuthSession session;
  final String code;
  final String qrPayload;
  final String scenario;

  static Future<RedeemFixture> read() async {
    // Do not include file contents or a caught exception in failures: both may
    // contain a bearer token or a live link code.
    try {
      final data = jsonDecode(await File(redeemFixturePath).readAsString());
      if (data is! Map<String, dynamic>) throw const FormatException();
      final sessionJson = data['session'];
      final code = data['code'];
      final qrPayload = data['qr_payload'];
      final scenario = data['scenario'];
      if (sessionJson is! Map<String, dynamic> ||
          code is! String ||
          qrPayload is! String ||
          scenario is! String) {
        throw const FormatException();
      }
      final session = AuthSession.fromJson(sessionJson);
      if (session.userId.isEmpty ||
          session.accessToken.isEmpty ||
          session.isExpired ||
          !session.profileComplete ||
          !isValidLinkCode(code) ||
          linkCodeFromQrPayload(qrPayload) != code) {
        throw const FormatException();
      }
      return RedeemFixture(
        session: session,
        code: code,
        qrPayload: qrPayload,
        scenario: scenario,
      );
    } on Object {
      throw StateError('Redeem fixture is missing or invalid');
    }
  }
}

Future<void> clearRedeemSession() => SecureAuthSessionStore().clear();

/// Install only the local fixture session, then start the production dependency
/// graph. `main()` constructs RemoteFamilyLinkRepository from AppConfig.
Future<void> startRedeemApp(WidgetTester tester, RedeemFixture fixture) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await SecureAuthSessionStore().write(fixture.session);
  await app.main();
  await tester.pump();
  await waitForRedeem(tester, find.byType(AppShell), step: 'home');
}

Future<void> waitForRedeem(
  WidgetTester tester,
  Finder finder, {
  required String step,
  Duration timeout = _timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(_step);
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Redeem step timed out: $step');
}

Future<void> tapRedeem(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(_step);
  await tester.tap(finder);
  await tester.pump(_step);
}

Future<void> openManualCode(WidgetTester tester) async {
  await tapRedeem(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Người thân'),
      ));
  await tapRedeem(tester, find.byKey(const Key('family-follow')));
  await tapRedeem(tester, find.byKey(const Key('follow-method-enter')));
  await waitForRedeem(tester, find.byKey(const Key('link-code-field')),
      step: 'enter-code');
}
