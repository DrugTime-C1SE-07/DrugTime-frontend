// Nhãn và icon của danh mục backend trên S08b/S08c
// (task adhoc-20261118-health-profile-catalog, AC8).
import 'package:drugtime_mobile/features/profile/domain/entities/health_setup.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/health_setup_controller.dart';
import 'package:drugtime_mobile/features/profile/presentation/widgets/health_setup_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host<T>(bool allergy, List<HealthSetupOption<T>> options) => MaterialApp(
      home: Scaffold(
        body: HealthSetupForm<T>(
          allergy: allergy,
          options: options,
          draft: HealthSetupDraft<T>(
              HealthSetupStep<T>(HealthSetupStatus.unreported)),
          onChanged: () {},
          onAdd: () {},
        ),
      ),
    );

Iterable<String> assetNames(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .map((image) => (image.image as AssetImage).assetName);

void main() {
  test('"Đái tháo đường type 2" hiển thị nhãn "Tiểu đường"', () {
    expect(
        healthSetupLabel(
            const HealthSetupOption<int>(1, 'Đái tháo đường type 2')),
        'Tiểu đường');
    expect(healthSetupLabel(const HealthSetupOption<int>(2, 'Tăng huyết áp')),
        'Tăng huyết áp');
  });

  testWidgets('S08c: hai bệnh nền seed có icon Figma 8 và 9', (tester) async {
    await tester.pumpWidget(host<int>(false, const [
      HealthSetupOption(1, 'Đái tháo đường type 2'),
      HealthSetupOption(2, 'Tăng huyết áp'),
    ]));

    expect(find.text('Tiểu đường'), findsOneWidget);
    expect(find.text('Tăng huyết áp'), findsOneWidget);
    expect(assetNames(tester), [
      'assets/icons/health_setup/8.png',
      'assets/icons/health_setup/9.png',
    ]);
  });

  testWidgets('S08b: dị ứng chưa có icon vẫn hiện tên, xếp sau mục có icon',
      (tester) async {
    await tester.pumpWidget(host<String>(true, const [
      HealthSetupOption('quinolone', 'Kháng sinh Quinolon', category: 'drug'),
      HealthSetupOption('penicillin', 'Penicillin', category: 'drug'),
      HealthSetupOption('sulfa', 'Sulfa', category: 'drug'),
    ]));

    expect(find.text('Kháng sinh Quinolon'), findsOneWidget);
    expect(find.byIcon(Icons.medical_services_outlined), findsNWidgets(2));
    // `sulfa` không còn icon riêng (đã bỏ khỏi danh mục).
    expect(assetNames(tester), ['assets/icons/health_setup/0.png']);
    final penicillin = tester.getTopLeft(find.text('Penicillin'));
    final quinolone = tester.getTopLeft(find.text('Kháng sinh Quinolon'));
    expect(
        penicillin.dy < quinolone.dy ||
            (penicillin.dy == quinolone.dy && penicillin.dx < quinolone.dx),
        isTrue);
  });
}
