import 'package:drugtime_mobile/features/interaction_check/data/models/interaction_check_mapper.dart';
import 'package:drugtime_mobile/features/interaction_check/data/repositories/in_memory_interaction_check_repository.dart';
import 'package:drugtime_mobile/features/interaction_check/domain/entities/interaction_check_result.dart';
import 'package:drugtime_mobile/features/interaction_check/presentation/widgets/interaction_warning_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InteractionCheckResult & Mapper', () {
    test('parse JSON to InteractionCheckResult correctly', () {
      final json = {
        'status': 'co_tuong_tac',
        'interactions': [
          {
            'ingredient_a_id': 1,
            'ingredient_a_name': 'Gemfibrozil',
            'ingredient_b_id': 2,
            'ingredient_b_name': 'Cerivastatin',
            'medication_a_id': 10,
            'medication_a_name': 'Lopid',
            'medication_b_id': 20,
            'medication_b_name': 'Lipobay',
            'severity_level': 4,
            'interaction_type': 'chong_chi_dinh',
            'handling_type': 'tranh_phoi_hop',
            'min_interval_hours': null,
            'description': 'Tiêu cơ vân kịch phát',
            'warning_message': '[CHỐNG CHỈ ĐỊNH] Phối hợp nguy hiểm',
            'source': 'Dược thư Quốc gia',
          }
        ],
        'insufficient_data_medications': [
          {
            'medication_id': 30,
            'medication_name': 'Thuốc Nam',
            'reason': 'Chưa map hoạt chất',
          }
        ],
        'disclaimer': nfr03Disclaimer,
      };

      final result = InteractionCheckMapper.fromJson(json);

      expect(result.status, InteractionCheckStatus.found);
      expect(result.hasInteractions, isTrue);
      expect(result.maxSeverity, 4);
      expect(result.hasContraindication, isTrue);
      expect(result.interactions.length, 1);

      final item = result.interactions.first;
      expect(item.ingredientAName, 'Gemfibrozil');
      expect(item.ingredientBName, 'Cerivastatin');
      expect(item.severityLevel, 4);
      expect(item.isContraindicated, isTrue);

      expect(result.insufficientDataMedications.length, 1);
      expect(result.insufficientDataMedications.first.medicationName, 'Thuốc Nam');
      expect(result.disclaimer, nfr03Disclaimer);
    });

    test('toRequestBody maps candidate and medication ids and doses', () {
      final body = InteractionCheckMapper.toRequestBody(
        candidateMedicationId: 10,
        candidateDoseAmount: 40.0,
        candidateDoseUnit: 'mg',
        medicationIds: [20, 30],
      );

      expect(body['candidate_medication_id'], 10);
      expect(body['candidate_dose_amount'], 40.0);
      expect(body['candidate_dose_unit'], 'mg');
      expect(body['medication_ids'], [20, 30]);
    });
  });

  group('InMemoryInteractionCheckRepository', () {
    test('returns stubResult or default noneFound', () async {
      final repo = InMemoryInteractionCheckRepository();
      final res = await repo.checkPatientInteractions(
        patientId: 'patient-123',
        candidateMedicationId: 1,
      );

      expect(res.status, InteractionCheckStatus.noneFound);
      expect(res.interactions, isEmpty);
      expect(res.disclaimer, nfr03Disclaimer);
    });
  });

  group('InteractionWarningDialog Widget', () {
    testWidgets('renders Severity 4 with Red Danger header and NFR03 Disclaimer',
        (tester) async {
      const result = InteractionCheckResult(
        status: InteractionCheckStatus.found,
        interactions: [
          InteractionFinding(
            ingredientAId: 1,
            ingredientAName: 'Gemfibrozil',
            ingredientBId: 2,
            ingredientBName: 'Cerivastatin',
            medicationAName: 'Lopid',
            medicationBName: 'Lipobay',
            severityLevel: 4,
            interactionType: 'chong_chi_dinh',
            handlingType: 'tranh_phoi_hop',
            description: 'Tiêu cơ vân kịch phát nguy hiểm tính mạng.',
            warningMessage: '[CHỐNG CHỈ ĐỊNH] Phối hợp nguy hiểm giữa Gemfibrozil và Cerivastatin',
            source: 'Dược thư Quốc gia Việt Nam',
          ),
        ],
        disclaimer: nfr03Disclaimer,
      );

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showInteractionWarningDialog(context, result);
                },
                child: const Text('Mở cảnh báo'),
              ),
            ),
          ),
        ),
      );

      // Nhấn mở dialog
      await tester.tap(find.text('Mở cảnh báo'));
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề cảnh báo mức 4
      expect(find.text('CẢNH BÁO CHỐNG CHỈ ĐỊNH'), findsOneWidget);
      expect(find.text('Lopid  ↔  Lipobay'), findsOneWidget);
      expect(find.text('Mức 4 · Chống chỉ định'), findsOneWidget);
      expect(find.textContaining('Tiêu cơ vân'), findsOneWidget);

      // Kiểm tra disclaimer NFR03 bắt buộc
      expect(find.text(nfr03Disclaimer), findsOneWidget);

      // Nhấn "Quay lại chỉnh sửa"
      await tester.tap(find.text('Quay lại chỉnh sửa'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });

    testWidgets('confirms dialog returns true on proceed', (tester) async {
      const result = InteractionCheckResult(
        status: InteractionCheckStatus.found,
        interactions: [
          InteractionFinding(
            ingredientAId: 10,
            ingredientAName: 'Amlodipin',
            ingredientBId: 20,
            ingredientBName: 'Simvastatin',
            medicationAName: 'Amlor 5mg',
            medicationBName: 'Zocor 20mg',
            severityLevel: 2,
            interactionType: 'phu_thuoc_lieu',
            handlingType: 'can_theo_doi',
            description: 'Tăng nồng độ statin, cần theo dõi đau cơ.',
            warningMessage: '[THẬN TRỌNG] Tăng nồng độ statin trong huyết tương.',
            source: 'QĐ BYT',
          ),
        ],
        disclaimer: nfr03Disclaimer,
      );

      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showInteractionWarningDialog(context, result);
                },
                child: const Text('Mở cảnh báo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở cảnh báo'));
      await tester.pumpAndSettle();

      expect(find.text('CẦN THẬN TRỌNG PHỐI HỢP'), findsOneWidget);
      expect(find.text('Mức 2 · Cần thận trọng'), findsOneWidget);

      // Nhấn "Đã hiểu & Tiếp tục"
      await tester.tap(find.text('Đã hiểu & Tiếp tục'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('renders InsufficientDataDialog and returns user decision',
        (tester) async {
      const result = InteractionCheckResult(
        status: InteractionCheckStatus.insufficientData,
        interactions: [],
        insufficientDataMedications: [
          InsufficientDataMedication(
            medicationId: 99,
            medicationName: 'Trà thảo mộc',
            reason: 'Chưa có hoạt chất đối soát',
          ),
        ],
        disclaimer: nfr03Disclaimer,
      );

      bool? decision;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  decision = await showInsufficientDataDialog(context, result);
                },
                child: const Text('Mở thiếu dữ liệu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở thiếu dữ liệu'));
      await tester.pumpAndSettle();

      expect(find.text('THIẾU DỮ LIỆU ĐỐI SOÁT TƯƠNG TÁC'), findsOneWidget);
      expect(find.text('Trà thảo mộc'), findsOneWidget);
      expect(find.text('Chưa có hoạt chất đối soát'), findsOneWidget);
      expect(find.text(nfr03Disclaimer), findsOneWidget);

      await tester.tap(find.text('Vẫn tiếp tục lưu'));
      await tester.pumpAndSettle();

      expect(decision, isTrue);
    });

    testWidgets('renders InteractionNetworkErrorDialog and returns user decision',
        (tester) async {
      bool? decision;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  decision = await showInteractionNetworkErrorDialog(context);
                },
                child: const Text('Mở lỗi mạng'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở lỗi mạng'));
      await tester.pumpAndSettle();

      expect(find.text('KHÔNG THỂ KIỂM TRA TƯƠNG TÁC'), findsOneWidget);
      expect(find.textContaining('Không thể kết nối đến máy chủ'), findsOneWidget);

      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();

      expect(decision, isFalse);
    });

    testWidgets(
        'renders InteractionWarningDialog displaying BOTH interactions and insufficient data',
        (tester) async {
      const mixedResult = InteractionCheckResult(
        status: InteractionCheckStatus.found,
        interactions: [
          InteractionFinding(
            ingredientAId: 1,
            ingredientAName: 'Gemfibrozil',
            ingredientBId: 2,
            ingredientBName: 'Cerivastatin',
            medicationAName: 'Lopid',
            medicationBName: 'Lipobay',
            severityLevel: 4,
            interactionType: 'chong_chi_dinh',
            handlingType: 'tranh_phoi_hop',
            description: 'Tiêu cơ vân kịch phát',
            warningMessage: '[CHỐNG CHỈ ĐỊNH] Phối hợp nguy hiểm',
            source: 'Dược thư Quốc gia',
          ),
        ],
        insufficientDataMedications: [
          InsufficientDataMedication(
            medicationId: 99,
            medicationName: 'Trà Atiso thảo dược',
            reason: 'Chưa có thông tin hoạt chất trong danh mục',
          ),
        ],
        disclaimer: nfr03Disclaimer,
      );

      bool? dialogDecision;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogDecision = await showInteractionWarningDialog(context, mixedResult);
                },
                child: const Text('Mở cảnh báo hỗn hợp'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở cảnh báo hỗn hợp'));
      await tester.pumpAndSettle();

      // Kiểm tra có đầy đủ cả 2 phần:
      // 1. Phần tương tác thuốc
      expect(find.text('CẢNH BÁO CHỐNG CHỈ ĐỊNH'), findsOneWidget);
      expect(find.textContaining('Lopid'), findsOneWidget);
      expect(find.textContaining('Lipobay'), findsOneWidget);

      // 2. Phần thuốc thiếu hoạt chất trong cùng đơn
      expect(find.text('Thuốc chưa đủ dữ liệu hoạt chất để đối soát:'), findsOneWidget);
      expect(find.textContaining('Trà Atiso thảo dược'), findsOneWidget);
      expect(find.textContaining('Chưa có thông tin hoạt chất'), findsOneWidget);

      // 3. Disclaimer pháp lý
      await tester.scrollUntilVisible(
        find.text(nfr03Disclaimer),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(nfr03Disclaimer), findsOneWidget);

      // Bấm Xác nhận & Tiếp tục
      await tester.tap(find.text('Xác nhận & Tiếp tục'));
      await tester.pumpAndSettle();

      expect(dialogDecision, isTrue);
    });
  });
}
