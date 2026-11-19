import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/personal_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/medical_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/notification_preferences_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/reminder_sound_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/invite_caregiver_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/caregivers_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/share_invite_link_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/link_request_result_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/link_request_controller.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family/presentation/screens/family_link_code_screen.dart';
import '../family_link/family_link_test_helpers.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/privacy_settings_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/scan_link_qr_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/link_consent_confirmation_screen.dart';
import 'package:drugtime_mobile/features/family_link/domain/entities/incoming_link_request.dart';
import 'package:drugtime_mobile/features/family_link/presentation/widgets/approve_link_sheet.dart';
import 'profile_test_helpers.dart';
import 'profile_widget_helpers.dart';

void main() {
  const capture = String.fromEnvironment('FLOW_CAPTURE_DIR');
  final screens = <String, Widget>{
    's08-1': const PersonalProfileScreen(),
    's08-2': const MedicalProfileScreen(),
    's08-3-empty': const CaregiversScreen(),
    's08-3a': const InviteCaregiverScreen(),
    's08-3b': const FamilyLinkCodeScreen(),
    's08-3g': const ShareInviteLinkScreen(),
    's08-3d': const LinkRequestResultScreen(outcome: LinkSubmitOutcome.waiting),
    's08-3f':
        const LinkRequestResultScreen(outcome: LinkSubmitOutcome.accepted),
    's08-4': const NotificationPreferencesScreen(),
    's08-4a': const ReminderSoundScreen(),
    's08-5': const ProfileSettingsScreen(),
    's08-6': const PrivacySettingsScreen(),
    's08-3c': ScanLinkQrScreen(
        scannerBuilder: (context, detect) =>
            const ColoredBox(color: Color(0xFF101818))),
    's08-3e': LinkConsentConfirmationScreen(
        args: LinkConsentConfirmationArgs(
            request: IncomingLinkRequest(
                linkId: 1,
                familyUserId: 'family-1',
                familyName: 'Nguyễn Văn Nam',
                requestedAt: DateTime.utc(2026, 11, 18)))),
  };
  for (final entry in screens.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${entry.key} layout and reachable content scale $scale',
          (t) async {
        final originalShadows = debugDisableShadows;
        try {
          final viewport =
              scale == 1 ? const Size(375, 812) : const Size(320, 640);
          final isProfile = entry.key == 's08-1' || entry.key == 's08-2';
          final controller = ProfileController(FakeProfileRepository());
          addTearDown(controller.dispose);
          const boundaryKey = Key('flow-render');
          if (capture.isNotEmpty) {
            await t.runAsync(() async {
              final font = FontLoader('ProfilePreview')
                ..addFont(File('C:/Windows/Fonts/segoeui.ttf')
                    .readAsBytes()
                    .then((v) => ByteData.sublistView(v)));
              await font.load();
              final normal = FontLoader('Roboto')
                ..addFont(File('C:/Windows/Fonts/segoeui.ttf')
                    .readAsBytes()
                    .then((v) => ByteData.sublistView(v)));
              await normal.load();
              final icons = FontLoader('MaterialIcons')
                ..addFont(File(
                        'D:/Captone/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
                    .readAsBytes()
                    .then((v) => ByteData.sublistView(v)));
              await icons.load();
            });
          }
          var theme = buildAppTheme();
          if (capture.isNotEmpty) {
            debugDisableShadows = false;
            const face = TextStyle(fontFamily: 'ProfilePreview');
            theme = theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'ProfilePreview'),
              primaryTextTheme:
                  theme.primaryTextTheme.apply(fontFamily: 'ProfilePreview'),
              appBarTheme: theme.appBarTheme.copyWith(
                  titleTextStyle:
                      face.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
              filledButtonTheme: FilledButtonThemeData(
                  style: theme.filledButtonTheme.style!
                      .copyWith(textStyle: const WidgetStatePropertyAll(face))),
              outlinedButtonTheme: OutlinedButtonThemeData(
                  style: (theme.outlinedButtonTheme.style ??
                          const ButtonStyle())
                      .copyWith(textStyle: const WidgetStatePropertyAll(face))),
              textButtonTheme: TextButtonThemeData(
                  style: theme.textButtonTheme.style!
                      .copyWith(textStyle: const WidgetStatePropertyAll(face))),
            );
          }
          final child = RepaintBoundary(
              key: boundaryKey,
              child: MediaQuery(
                  data: MediaQueryData(
                      size: viewport,
                      padding: const EdgeInsets.only(top: 44, bottom: 34),
                      viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
                      textScaler: TextScaler.linear(scale)),
                  child: Theme(
                      data: capture.isEmpty
                          ? theme
                          : theme.copyWith(
                              textTheme: theme.textTheme
                                  .apply(fontFamily: 'ProfilePreview')),
                      child: entry.value)));
          if (isProfile) {
            t.view.physicalSize = viewport;
            t.view.devicePixelRatio = 1;
            addTearDown(t.view.reset);
            await t.pumpWidget(profileApp(controller, child,
                textScale: scale, previewFont: capture.isNotEmpty));
          } else {
            await pumpFamilyLink(t, child,
                repository: InMemoryFamilyLinkRepository());
            t.view.physicalSize = viewport;
            t.view.devicePixelRatio = 1;
          }
          await t.pumpAndSettle();
          if (capture.isNotEmpty &&
              (entry.key == 's08-3d' || entry.key == 's08-3f')) {
            await t.runAsync(() async {
              await precacheImage(
                  AssetImage(entry.key == 's08-3d'
                      ? 'assets/icons/mascot-thinking.png'
                      : 'assets/icons/mascot-happy.png'),
                  t.element(find.byKey(boundaryKey)));
            });
            await t.pumpAndSettle();
          }
          expect(t.takeException(), isNull);
          if (capture.isNotEmpty && scale == 1) {
            await t.runAsync(() async {
              final boundary = t
                  .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
              final snapshot = await boundary.toImage(pixelRatio: 2);
              final bytes =
                  await snapshot.toByteData(format: ui.ImageByteFormat.png);
              await Directory(capture).create(recursive: true);
              await File('$capture/${entry.key}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              snapshot.dispose();
            });
          }
          final scroll = find.byType(Scrollable);
          if (scroll.evaluate().isNotEmpty) {
            await t.drag(scroll.first, const Offset(0, -1200));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          }
        } finally {
          debugDisableShadows = originalShadows;
        }
      });
    }
  }
  testWidgets(
      'approval sheet large text stays scrollable and requires explicit agreement',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    bool? approved;
    final request = IncomingLinkRequest(
        linkId: 1,
        familyUserId: 'family-1',
        familyName: 'Nguyễn Văn Nam',
        requestedAt: DateTime.utc(2026, 11, 18));
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                body: FilledButton(
                    onPressed: () async {
                      approved = await showApproveLinkSheet(context, request);
                    },
                    child: const Text('Mở xác nhận'))))));
    await t.tap(find.text('Mở xác nhận'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final confirm = find.byKey(const Key('approve-confirm'));
    expect(t.widget<FilledButton>(confirm).onPressed, isNull);
    final checkbox = find.byKey(const Key('approve-consent-checkbox'));
    await t.ensureVisible(checkbox);
    await t.pumpAndSettle();
    await t.tap(checkbox);
    await t.pumpAndSettle();
    await t.ensureVisible(confirm);
    await t.pumpAndSettle();
    await t.tap(confirm);
    await t.pumpAndSettle();
    expect(approved, isTrue);
    expect(t.takeException(), isNull);
  });
}
