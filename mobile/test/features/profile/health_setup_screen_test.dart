import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/health_profile_intro_screen.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_setup.dart';
import 'package:drugtime_mobile/features/profile/domain/repositories/health_setup_repository.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/health_setup_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/health_setup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/notification/device_token_coordinator_test.dart'
    show tokenSession;

class _Repository implements HealthSetupRepository {
  HealthSetupSnapshot current = const HealthSetupSnapshot(
    '1',
    HealthSetupStep(HealthSetupStatus.unreported),
    HealthSetupStep(HealthSetupStatus.unreported),
  );
  int saveCalls = 0;
  bool loseResponse = false;
  bool failLoad = false;
  bool emptyConditionCatalog = false;
  HealthSetupStep<String>? submittedAllergies;
  HealthSetupStep<String>? readbackAllergies;

  @override
  Future<HealthSetupSnapshot> read() async {
    if (failLoad) throw const FormatException();
    return current;
  }

  @override
  Future<List<HealthSetupOption<String>>> allergens() async => const [
        HealthSetupOption('penicillin', 'Penicillin', category: 'drug'),
        HealthSetupOption('seafood', 'Hải sản', category: 'food'),
      ];

  @override
  Future<List<HealthSetupOption<int>>> conditions() async =>
      emptyConditionCatalog
          ? const []
          : const [
              HealthSetupOption(1, 'Hypertension'),
              HealthSetupOption(2, 'Diabetes mellitus'),
            ];

  @override
  Future<HealthSetupSnapshot> save(
    String revision, {
    HealthSetupStep<String>? allergies,
    HealthSetupStep<int>? conditions,
  }) async {
    expect(revision, current.revision);
    saveCalls++;
    submittedAllergies = allergies;
    current = HealthSetupSnapshot(
        '2',
        readbackAllergies ?? allergies ?? current.allergies,
        conditions ?? current.conditions);
    if (loseResponse) throw const HealthSetupSaveException(needsReadback: true);
    return current;
  }
}

void main() {
  testWidgets('Authenticated onboarding returns home directly after saving',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = AuthController(InMemoryAuthRepository(
      initialSession: tokenSession('health-setup'),
      simulatedDelay: Duration.zero,
    ));
    final consents = ConsentController(InMemoryConsentRepository(
      granted: {ConsentPurpose.terms, ConsentPurpose.healthData},
    ));
    addTearDown(auth.dispose);
    addTearDown(consents.dispose);
    await auth.initSession();
    final repository = _Repository();

    await tester.pumpWidget(AuthScope(
      controller: auth,
      child: ConsentScope(
        controller: consents,
        child: MaterialApp(
          onGenerateRoute: (settings) =>
              onGenerateRoute(settings, healthSetupRepository: repository),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.healthProfileIntro,
                ),
                child: const Text('Trang chủ'),
              ),
            ),
          ),
        ),
      ),
    ));

    Future<void> tap(String label) async {
      final target = find.text(label).hitTestable();
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap('Trang chủ');
    await tester.ensureVisible(find.text('Tiếp tục đến dị ứng'));
    await tap('Tiếp tục đến dị ứng');
    await tap('Penicillin');
    await tap('Tiếp tục');
    await tap('Tôi không có bệnh nền đã biết');
    await tap('Tiếp tục');
    expect(repository.saveCalls, 1);

    await tester.tap(find.text('Vào ứng dụng'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(find.byType(HealthProfileIntroScreen, skipOffstage: false),
        findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty backend condition catalog still allows custom declaration',
      (tester) async {
    final repo = _Repository()..emptyConditionCatalog = true;
    await tester
        .pumpWidget(MaterialApp(home: HealthSetupScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Danh mục bệnh nền chưa có mục nào'),
        findsOneWidget);
    expect(find.text('Tăng huyết áp'), findsNothing);
    expect(find.text('Tôi không có bệnh nền đã biết'), findsOneWidget);
    await tester.tap(find.text('Thêm bệnh nền khác'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bệnh nền đã khai');
    await tester.pump();
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(repo.current.conditions.ids, isEmpty);
    expect(repo.current.conditions.names, ['Bệnh nền đã khai']);
    expect(find.text('Đã lưu hồ sơ sức khỏe'), findsOneWidget);
  });

  testWidgets('selects two allergens, keeps draft on back and saves none known',
      (tester) async {
    final repo = _Repository();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<bool>(
                    builder: (_) => HealthSetupScreen(repository: repo))),
            child: const Text('Trang chủ'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Penicillin'));
    await tester.tap(find.text('Hải sản'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Tiểu đường'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tôi không có bệnh nền đã biết'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu hồ sơ sức khỏe'), findsOneWidget);
    expect(find.text('Không có bệnh nền đã biết'), findsOneWidget);
    expect(repo.submittedAllergies?.ids,
        unorderedEquals(['penicillin', 'seafood']));
    expect(repo.saveCalls, 1);
    await tester.tap(find.text('Vào ứng dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Trang chủ'), findsOneWidget);
  });

  testWidgets('load error offers retry and does not show form', (tester) async {
    final repo = _Repository()..failLoad = true;
    await tester
        .pumpWidget(MaterialApp(home: HealthSetupScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được hồ sơ sức khỏe.'), findsOneWidget);
    expect(find.text('Bạn dị ứng với gì?'), findsNothing);
    repo.failLoad = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn dị ứng với gì?'), findsOneWidget);
  });

  test('readback confirms a lost save response without sending twice',
      () async {
    final repo = _Repository()..loseResponse = true;
    final controller = HealthSetupController(repo);
    addTearDown(controller.dispose);
    await controller.load();
    controller.conditionDraft.toggleNone();
    expect(await controller.finish(includeConditions: true),
        HealthSetupSaveResult.saved);
    expect(controller.saved!.conditions.status, HealthSetupStatus.noneKnown);
    expect(repo.saveCalls, 1);
  });

  for (final name in ['Hải sản', 'Hải Sản']) {
    test('lost save response with stored name "$name"', () async {
      const draftName = 'Ha\u0309i sản';
      final repo = _Repository()
        ..loseResponse = true
        ..readbackAllergies =
            HealthSetupStep(HealthSetupStatus.reported, names: [name]);
      final controller = HealthSetupController(repo);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.allergyDraft.addCustom(draftName), isTrue);
      controller.includeAllergies(true);

      final result = await controller.finish(includeConditions: false);

      expect(repo.saveCalls, 1);
      expect(repo.submittedAllergies!.names, [draftName]);
      if (name == 'Hải sản') {
        expect(result, HealthSetupSaveResult.saved);
        expect(controller.saved!.allergies.names, [name]);
        expect(controller.conflict, isFalse);
      } else {
        expect(result, HealthSetupSaveResult.failed);
        expect(controller.conflict, isTrue);
        expect(controller.saved, isNull);
        expect(controller.allergyDraft.names, [draftName]);
      }
    });
  }
}
