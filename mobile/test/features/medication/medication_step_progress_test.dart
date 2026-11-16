import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/dosage_form_icon.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_form_fields.dart';
import 'package:drugtime_mobile/features/medication/presentation/widgets/medication_step_progress.dart';
import 'package:drugtime_mobile/features/medication_capture/domain/ocr_models.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/capture_analyzing_screen.dart';
import 'package:drugtime_mobile/features/medication_capture/presentation/screens/ocr_candidates_screen.dart';

void main() {
  group('AC1 · MedicationStepProgress (Thanh tiến trình 3 bước)', () {
    // Theo thiết kế Figma StepProgress/1of3, 2of3, 3of3:
    // chỉ hiện nhãn tên bước ở TRÊN vạch ĐANG ACTIVE, các vạch khác không có chữ.
    testWidgets('step 0: chỉ hiện nhãn "Thêm thuốc", không hiện nhãn bước khác',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MedicationStepProgress(currentStep: 0),
          ),
        ),
      );

      // Chỉ nhãn active được hiện
      expect(find.text('Thêm thuốc'), findsOneWidget);
      expect(find.text('Lịch uống'), findsNothing);
      expect(find.text('Xác nhận'), findsNothing);

      // Tuyệt đối không xuất hiện chữ "Bước x/3"
      expect(find.textContaining('Bước'), findsNothing);
      expect(find.textContaining('/3'), findsNothing);
    });

    testWidgets('chuyển step đổi nhãn active đúng, luôn chỉ hiện 1 nhãn',
        (tester) async {
      for (int step = 0; step <= 2; step++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MedicationStepProgress(currentStep: step),
            ),
          ),
        );
        // Nhãn active xuất hiện đúng 1 lần
        expect(
            find.text(MedicationStepProgress.stepLabels[step]), findsOneWidget);
        // Các nhãn của bước khác không xuất hiện
        for (int j = 0; j < MedicationStepProgress.stepLabels.length; j++) {
          if (j != step) {
            expect(
                find.text(MedicationStepProgress.stepLabels[j]), findsNothing);
          }
        }
        expect(find.textContaining('Bước'), findsNothing);
      }
    });

    testWidgets('nhãn active nằm trực tiếp trên vạch của bước tương ứng',
        (tester) async {
      double? prevX;
      for (int step = 0; step <= 2; step++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MedicationStepProgress(currentStep: step),
            ),
          ),
        );
        final labelFinder = find.text(MedicationStepProgress.stepLabels[step]);
        final topLeft = tester.getTopLeft(labelFinder);
        if (prevX != null) {
          // Nhãn bước sau phải nằm dịch về bên phải hơn nhãn bước trước (trên vạch tương ứng)
          expect(topLeft.dx > prevX, isTrue);
        }
        prevX = topLeft.dx;
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

    testWidgets(
        'DosageFormIcon và DosageFormTile render với màu mặc định brand',
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

  group('AC3 · CaptureAnalyzingScreen (Màn hình nhận diện OCR S07-O2)', () {
    testWidgets(
        'hiển thị 3 trạng thái phân tích và KHÔNG chứa disclaimer xử lý trên máy',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CaptureAnalyzingScreen(
            step: 1,
            progress: 0.5,
            onCancel: () {},
          ),
        ),
      );

      // Hiển thị 3 trạng thái nhận diện theo Figma / SRS
      expect(find.text('Đã chụp ảnh vỏ thuốc'), findsOneWidget);
      expect(find.text('Đang đọc chữ trên vỏ'), findsOneWidget);
      expect(find.text('Đối chiếu danh mục thuốc'), findsOneWidget);

      // Tuyệt đối không chứa dòng disclaimer
      expect(find.textContaining('Ảnh chỉ xử lý trên máy'), findsNothing);
      expect(find.textContaining('không gửi đi'), findsNothing);
      expect(find.textContaining('trên máy'), findsNothing);
    });
  });

  group('AC4 · OcrCandidatesScreen (Kết quả nhận diện OCR S07-O2r)', () {
    testWidgets('chọn "Đúng thuốc này" gọi callback ứng viên', (tester) async {
      final candidates = [
        const OcrCandidate(
          id: 101,
          name: 'Panadol Extra',
          activeIngredient: 'Paracetamol, Caffeine',
          strengthText: '500mg/65mg',
          dosageForm: 'Viên nén dài',
          hasActiveIngredients: true,
          score: 0.95,
        ),
      ];
      final result = OcrMatchResult(
        status: OcrMatchStatus.matched,
        items: candidates,
        preselectedId: 101,
        suggestedQuery: 'Panadol',
        reasons: [],
      );

      OcrCandidate? selectedCandidate;

      await tester.pumpWidget(
        MaterialApp(
          home: OcrCandidatesScreen(
            result: result,
            onRetake: () {},
            onExit: () {},
            onSelectCandidate: (c) => selectedCandidate = c,
          ),
        ),
      );

      expect(find.text('Panadol Extra'), findsOneWidget);
      expect(find.text('95% khớp'), findsOneWidget);
      expect(find.text('Hàm lượng: 500mg/65mg'), findsOneWidget);
      expect(find.text('Dạng: Viên nén dài'), findsOneWidget);
      expect(find.text('Đúng thuốc này'), findsOneWidget);

      await tester.tap(find.text('Đúng thuốc này'));
      await tester.pumpAndSettle();

      expect(selectedCandidate, isNotNull);
      expect(selectedCandidate!.name, 'Panadol Extra');
      expect(selectedCandidate!.id, 101);
    });
  });

  group('AC5 · S07-M2i · DrugInfoSheet (Xem chi tiết thông tin thuốc)', () {
    testWidgets(
        'DrugInfoSheet hiển thị đầy đủ thông tin thuốc và cảnh báo thận trọng',
        (tester) async {
      const drug = DrugCatalogItem(
        id: '1',
        name: 'Paracetamol 500mg',
        activeIngredient: 'Paracetamol',
        strength: '500 mg',
        dosageForm: 'Viên nén',
        unit: 'viên',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDrugInfoSheet(context, drug),
                child: const Text('Mở thông tin'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở thông tin'));
      await tester.pumpAndSettle();

      expect(find.text('Paracetamol 500mg'), findsOneWidget);
      expect(find.text('Hoạt chất'), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);
      expect(find.text('Hàm lượng'), findsOneWidget);
      expect(find.text('500 mg'), findsOneWidget);
      expect(find.text('Dạng bào chế'), findsOneWidget);
      expect(find.text('Viên nén'), findsOneWidget);
      expect(find.text('Liều tối đa'), findsOneWidget);
      expect(find.text('4 g/ngày (người lớn)'), findsOneWidget);
      expect(find.text('Công dụng'), findsOneWidget);
      expect(find.text('Nguồn: Dược thư Quốc gia Việt Nam'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('AC6 · S07-M4 · MedicationSuccessView (Màn hình hoàn tất thêm thuốc)',
      () {
    testWidgets(
        'MedicationSuccessView hiển thị ăn mừng, tên thuốc, badge an toàn và 2 nút hành động',
        (tester) async {
      final medication = Medication(
        id: 'med_1',
        catalogId: '1',
        name: 'Paracetamol 500mg',
        activeIngredient: 'Paracetamol',
        strength: '500 mg',
        unit: 'viên',
        dosePerIntake: 1,
        frequency: DoseFrequency.twice,
        timing: IntakeTiming.afterMeal,
        times: const [DoseTime(8, 0), DoseTime(20, 0)],
      );

      bool wentHome = false;
      bool addedAnother = false;

      await tester.pumpWidget(
        MaterialApp(
          home: MedicationSuccessView(
            medication: medication,
            noInteractionsFound: true,
            onHome: () => wentHome = true,
            onAddAnother: () => addedAnother = true,
          ),
        ),
      );

      expect(find.text('Đã thêm thuốc!'), findsOneWidget);
      expect(find.text('Paracetamol 500mg · 2 lần/ngày'), findsOneWidget);
      expect(find.text('Không có tương tác nguy hiểm'), findsOneWidget);
      expect(find.text('Về trang chủ'), findsOneWidget);
      expect(find.text('Thêm thuốc khác'), findsOneWidget);

      await tester.tap(find.text('Về trang chủ'));
      expect(wentHome, isTrue);

      await tester.tap(find.text('Thêm thuốc khác'));
      expect(addedAnother, isTrue);
    });
  });
}
