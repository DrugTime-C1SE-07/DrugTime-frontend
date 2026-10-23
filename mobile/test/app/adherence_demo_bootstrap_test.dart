import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/main.dart' as application;
import 'package:drugtime_mobile/app/adherence_demo_app.dart';
import 'package:drugtime_mobile/app/missing_config_app.dart';
import 'package:drugtime_mobile/core/config/app_config.dart';

void main() {
  testWidgets(
      'bootstrap uses only the explicitly selected source, no external work',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var externalCalls = 0;
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final name in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'dexterous.com/flutter/local_notifications',
      'com.tekartik.sqflite',
      'dev.fluttercommunity.plus/share',
      'com.llfbandit.app_links/messages',
      'dev.steenbakker.mobile_scanner/scanner/method'
    ]) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, (_) async {
        externalCalls++;
        throw StateError('Unexpected platform service in isolated bootstrap');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    await HttpOverrides.runZoned(() => application.main(),
        createHttpClient: (_) {
      externalCalls++;
      throw StateError('Unexpected HTTP client in isolated bootstrap');
    });
    await tester.pumpAndSettle();
    if (AppConfig.previewEnabled) {
      expect(find.byType(AdherenceDemoApp), findsOneWidget);
      expect(find.text('Mẫu'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(const Key('demo-enter')), findsNothing);
      expect(find.text('80%'), findsOneWidget);
    } else {
      expect(AppConfig.apiBaseUrl, isEmpty);
      expect(find.byType(MissingConfigApp), findsOneWidget);
      expect(find.byType(AdherenceDemoApp), findsNothing);
    }
    expect(externalCalls, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
