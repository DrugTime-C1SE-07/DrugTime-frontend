import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/dosage_form_icon.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_step_progress.dart';

void main() {
  group('AC1 · MedicationStepProgress (Thanh tiến trình 3 bước)', () {
    testWidgets('hiển thị 3 vạch tiến trình và nhãn tương ứng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MedicationStepProgress(currentStep: 0),
          ),
        ),
      );

      // 3 bước
      expect(find.text('Thêm thuốc'), findsOneWidget);
      expect(find.text('Lịch uống'), findsOneWidget);
      expect(find.text('Xác nhận'), findsOneWidget);

      // Tuyệt đối không xuất hiện chữ "Bước x/3"
      expect(find.textContaining('Bước'), findsNothing);
      expect(find.textContaining('/3'), findsNothing);
    });

    testWidgets('chuyển step đổi trạng thái active/inactive đúng', (tester) async {
      for (int step = 0; step <= 2; step++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MedicationStepProgress(currentStep: step),
            ),
          ),
        );
        expect(find.text(MedicationStepProgress.stepLabels[step]), findsOneWidget);
        expect(find.textContaining('Bước'), findsNothing);
      }
    });
  });

  group('AC2 · DosageFormIcon (Ánh xạ dạng thuốc tự động)', () {
    test('parseDosageForm phân loại chính xác các dạng bào chế phổ biến', () {
      expect(parseDosageForm('Viên nén bao phim'), DosageFormType.tablet);
      expect(parseDosageForm('Viên sủi 500mg'), DosageFormType.tablet);
      expect(parseDosageForm('Viên nang cứng'), DosageFormType.capsule);
      expect(parseDosageForm('Nang mềm'), DosageFormType.capsule);
      expect(parseDosageForm('Siro ho'), DosageFormType.liquid);
      expect(parseDosageForm('Dung dịch uống'), DosageFormType.liquid);
      expect(parseDosageForm('Gói bột pha hỗn dịch'), DosageFormType.powder);
      expect(parseDosageForm('Thuốc cốm'), DosageFormType.powder);
      expect(parseDosageForm('Thuốc nhỏ mắt'), DosageFormType.drops);
      expect(parseDosageForm('Thuốc xịt mũi'), DosageFormType.spray);
      expect(parseDosageForm('Kem bôi da'), DosageFormType.cream);
      expect(parseDosageForm('Gel bôi giảm đau'), DosageFormType.cream);
      expect(parseDosageForm('Bút tiêm'), DosageFormType.injection);
      expect(parseDosageForm(''), DosageFormType.other);
      expect(parseDosageForm(null), DosageFormType.other);
    });

    testWidgets('DosageFormIcon và DosageFormTile render với màu mặc định brand',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DosageFormIcon(dosageForm: 'Viên nén'),
                DosageFormTile(dosageForm: 'Viên nang'),
                DosageFormTile(dosageForm: 'Siro'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(DosageFormIcon), findsNWidgets(3));
      expect(find.byType(DosageFormTile), findsNWidgets(2));
    });
  });
}
