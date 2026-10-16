import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/core/utils/app_assets.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'profile_test_helpers.dart';

void main() {
  for (final use401 in [false, true]) {
    testWidgets(
        'app clears profile/avatar and delayed response on ${use401 ? '401' : 'logout'}',
        (tester) async {
      final repo = FakeProfileRepository();
      final auth = AuthController(InMemoryAuthRepository(
          simulatedDelay: Duration.zero,
          initialSession: AuthSession(
              userId: 'one',
              accessToken: 'test',
              expiresAt: DateTime.now().add(const Duration(days: 1)),
              profileComplete: true)));
      addTearDown(auth.dispose);
      await tester.pumpWidget(DrugTimeApp(
          authController: auth,
          profileRepository: repo,
          medicationRepository: InMemoryMedicationRepository(),
          initialRoute: AppRoutes.profile));
      await tester.pumpAndSettle();
      final c = ProfileScope.read(tester.element(find.text('Hồ sơ')));
      c.selectAvatar(AppAssets.profileAvatars.first);
      repo.pendingRead = Completer();
      final pending = c.load();
      if (use401) {
        await auth.handleUnauthorized();
      } else {
        await auth.signOut();
      }
      await tester.pumpAndSettle();
      expect(c.profile, isNull);
      expect(c.avatar, isNull);
      repo.pendingRead!.complete(repo.value);
      await pending;
      await tester.pumpAndSettle();
      expect(c.profile, isNull);
      expect(find.text('Nguyễn Mai'), findsNothing);
    });
  }
  testWidgets(
      'app consent withdrawal clears form without waiting for next HTTP response',
      (tester) async {
    final repo = FakeProfileRepository();
    final auth = AuthController(InMemoryAuthRepository(
        simulatedDelay: Duration.zero,
        initialSession: AuthSession(
            userId: 'one',
            accessToken: 'test',
            expiresAt: DateTime.now().add(const Duration(days: 1)),
            profileComplete: true)));
    addTearDown(auth.dispose);
    await tester.pumpWidget(DrugTimeApp(
        authController: auth,
        profileRepository: repo,
        medicationRepository: InMemoryMedicationRepository(),
        consentRepository: InMemoryConsentRepository(
            granted: {ConsentPurpose.healthData, ConsentPurpose.terms}),
        initialRoute: AppRoutes.personalProfile));
    await tester.pumpAndSettle();
    final context = tester.element(find.byKey(const Key('profile-name')));
    final c = ProfileScope.read(context);
    final consents = ConsentScope.read(context);
    await consents.load();
    await tester.enterText(
        find.byKey(const Key('profile-name')), 'Private draft');
    await consents.withdraw(ConsentPurpose.healthData);
    await tester.pumpAndSettle();
    expect(c.denied, isTrue);
    expect(c.profile, isNull);
    expect(find.text('Private draft'), findsNothing);
    expect(find.byKey(const Key('profile-name')), findsNothing);
  });
}
