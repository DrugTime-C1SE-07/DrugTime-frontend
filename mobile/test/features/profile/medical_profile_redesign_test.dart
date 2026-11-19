// Hồ sơ sức khỏe thiết kế lại + màn Tình trạng sinh lý (N2, N8, N10, N11).
import 'package:drugtime_mobile/features/profile/domain/entities/condition.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_setup.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/medical_profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/physiological_state_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';
import 'package:drugtime_mobile/features/profile/presentation/widgets/health_setup_form.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_controller.dart';
import 'package:drugtime_mobile/shared/widgets/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_test_helpers.dart';
import 'profile_widget_helpers.dart';

const _diabetes =
    ProfileCondition(id: 1, conditionId: 3, name: 'Tăng huyết áp');
const _pregnant = ProfileCondition(
    id: 2,
    conditionId: 30,
    name: 'Đang mang thai',
    category: ConditionCategory.physiologicalState);

Future<(ProfileController, FakeHealthSetupRepository)> _pump(
    WidgetTester tester,
    {String gender = 'nu',
    double scale = 1,
    Size size = const Size(375, 812),
    HealthSetupSnapshot? setup,
    Widget Function(FakeHealthSetupRepository repo)? screen}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final profiles = FakeProfileRepository()
    ..value = HealthProfile(
        fullName: 'Nguyễn Mai',
        gender: gender,
        conditions: const [_diabetes, _pregnant]);
  final controller = ProfileController(profiles);
  addTearDown(controller.dispose);
  final repo = FakeHealthSetupRepository(initial: setup);
  await tester.pumpWidget(profileApp(
      controller, screen?.call(repo) ?? MedicalProfileScreen(repository: repo),
      textScale: scale));
  await tester.pumpAndSettle();
  return (controller, repo);
}

MascotMood _mood(WidgetTester tester) =>
    tester.widget<MascotView>(find.byType(MascotView)).controller.mood;

void main() {
  testWidgets(
      'setup-style icon tiles, no "unavailable", no routine save chip, diseases exclude pregnancy (AC13, AC16)',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('health-allergy-section')), findsOneWidget);
    expect(find.byKey(const Key('health-disease-section')), findsOneWidget);
    expect(find.byType(HealthSetupOptionGrid<String>), findsOneWidget);
    expect(find.byType(HealthSetupOptionGrid<int>), findsOneWidget);
    // Same groups as the setup flow.
    expect(find.text('Thuốc'), findsOneWidget);
    expect(find.text('Thực phẩm'), findsOneWidget);
    // Feedback 20/11: no "Tự động lưu" chip while nothing is wrong.
    expect(find.byKey(const Key('health-save-status')), findsNothing);
    expect(find.textContaining('chưa khả dụng'), findsNothing);
    expect(find.byType(MascotView), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('physiological-tile')), 200);
    expect(find.byKey(const Key('physiological-tile')), findsOneWidget);
    // Pregnancy is not a chronic-disease tile.
    expect(find.text('Đang mang thai'), findsNothing);
    // Feedback 20/11: no subtype/stage rows under the diseases.
    expect(find.textContaining('phân loại, giai đoạn'), findsNothing);
  });

  testWidgets('men do not see the physiological row (AC26)', (tester) async {
    await _pump(tester, gender: 'nam');
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('physiological-tile')), findsNothing);
    expect(find.byKey(const Key('health-disease-section')), findsOneWidget);
  });

  testWidgets('profile menu counts chronic diseases only (AC16)',
      (tester) async {
    await _pump(tester, screen: (_) => const ProfileScreen());
    expect(find.text('1 bệnh nền'), findsOneWidget);
  });

  testWidgets(
      'tapping an allergy tile saves once, quietly; mascot shields (AC21, AC23)',
      (tester) async {
    final (_, repo) = await _pump(tester);
    await tester.tap(find.text('Hải sản'));
    await tester.pump();
    expect(_mood(tester), MascotMood.protect);
    await tester.pumpAndSettle();
    expect(repo.saves, 1, reason: 'one request per tap');
    expect(
        repo.current.allergies.ids, unorderedEquals(['penicillin', 'seafood']));
    expect(find.byKey(const Key('health-save-status')), findsNothing);
  });

  testWidgets('choosing a disease tile saves the chronic step (AC13)',
      (tester) async {
    final (_, repo) = await _pump(tester);
    final tile = find.descendant(
        of: find.byKey(const Key('health-disease-section')),
        matching: find.text('Tăng huyết áp'));
    await tester.scrollUntilVisible(tile, 200);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(repo.saved, ['conditions']);
    expect(repo.current.conditions.ids, [3]);
  });

  testWidgets('deselecting saves at once with no "Đã bỏ" / "Hoàn tác" snackbar',
      (tester) async {
    final (_, repo) = await _pump(tester,
        setup: const HealthSetupSnapshot(
            '1',
            HealthSetupStep(HealthSetupStatus.reported,
                ids: ['penicillin', 'seafood']),
            HealthSetupStep(HealthSetupStatus.unreported)));
    await tester.tap(find.text('Hải sản'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Hoàn tác'), findsNothing);
    expect(find.textContaining('Đã bỏ'), findsNothing);
    expect(repo.saves, 1, reason: 'sent right away, no debounce');
    expect(repo.current.allergies.ids, ['penicillin']);
  });

  testWidgets('quick taps are queued and all saved; leaving at once keeps them',
      (tester) async {
    final (_, repo) = await _pump(tester);
    await tester.tap(find.text('Hải sản'));
    await tester
        .tap(find.text('Cephalosporin (Cefalexin, Ceftriaxon, Cefuroxim…)'));
    // Close the screen before anything settles.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(repo.current.allergies.ids,
        unorderedEquals(['penicillin', 'seafood', 'cephalosporin']));
  });

  testWidgets(
      'deselecting the last allergy asks for a choice instead of saving',
      (tester) async {
    final (_, repo) = await _pump(tester);
    await tester.tap(find.text('Penicillin'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(repo.saves, 0);
    expect(find.text('Chưa lưu'), findsOneWidget);
  });

  testWidgets('a failed save shows "Lưu lỗi" and a worried mascot',
      (tester) async {
    final (_, repo) = await _pump(tester);
    repo.failSave = true;
    await tester.ensureVisible(find.byKey(const Key('allergy-none')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('allergy-none')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    // Said where the user is, and on the hero card at the top.
    expect(find.text('Chưa lưu được thay đổi.'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('Lưu lỗi – Thử lại'), findsOneWidget);
    expect(_mood(tester), MascotMood.concerned);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('every allergy and disease tile has the same size at $scale',
        (tester) async {
      await _pump(tester, scale: scale);
      Set<Size> sizesIn(Key section) => {
            for (final e in find
                .descendant(
                    of: find.byKey(section),
                    matching: find.byWidgetPredicate((w) =>
                        w is SizedBox &&
                        w.height != null &&
                        w.width != null &&
                        w.child is Semantics),
                    skipOffstage: false)
                .evaluate())
              (e.renderObject! as RenderBox).size
          };
      final allergy = sizesIn(const Key('health-allergy-section'));
      expect(allergy, hasLength(1), reason: 'allergy tiles: $allergy');
      await tester.scrollUntilVisible(
          find.byKey(const Key('condition-none')), 200);
      final disease = sizesIn(const Key('health-disease-section'));
      expect(disease, hasLength(1), reason: 'disease tiles: $disease');
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 640), const Size(375, 812)]) {
    testWidgets('no overflow at 130% text on $size (AC14)', (tester) async {
      await _pump(tester, scale: 1.3, size: size);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  group('PhysiologicalStateScreen (AC13b, AC25)', () {
    Widget screen(FakeHealthSetupRepository repo) =>
        PhysiologicalStateScreen(repository: repo);

    testWidgets('lists only physiological states plus "Không"', (tester) async {
      await _pump(tester, screen: screen);
      expect(find.text('Đang mang thai'), findsOneWidget);
      expect(find.text('Đang cho con bú'), findsOneWidget);
      expect(find.text('Tăng huyết áp'), findsNothing);
      expect(find.byKey(const Key('physiological-none')), findsOneWidget);
      expect(find.textContaining('phải bệnh'), findsWidgets);
    });

    testWidgets('choosing pregnancy saves it and the mascot cradles',
        (tester) async {
      final (_, repo) = await _pump(tester, screen: screen);
      await tester.tap(find.byKey(const Key('physiological-option-30')));
      await tester.pump();
      expect(_mood(tester), MascotMood.cradle);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(repo.current.physiological.ids, [30]);
      expect(repo.saved, ['physiological']);
    });

    testWidgets('"Không" is exclusive and stored explicitly (Q6)',
        (tester) async {
      final (_, repo) = await _pump(tester, screen: screen);
      await tester.tap(find.byKey(const Key('physiological-option-30')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('physiological-none')));
      await tester.pumpAndSettle();
      expect(repo.current.physiological.status, HealthSetupStatus.noneKnown);
      expect(repo.current.physiological.ids, isEmpty);
    });
  });
}
