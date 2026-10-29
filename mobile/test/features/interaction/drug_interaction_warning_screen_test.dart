import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/features/interaction/domain/entities/drug_interaction_result.dart';
import 'package:drugtime_mobile/features/interaction/presentation/screens/drug_interaction_warning_screen.dart';
import 'package:drugtime_mobile/features/interaction/presentation/widgets/interaction_pair_card.dart';
import 'package:drugtime_mobile/features/interaction/presentation/widgets/mandatory_disclaimer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp({
  required DrugInteractionReport report,
  VoidCallback? onAcknowledge,
  VoidCallback? onConsultDoctor,
}) {
  return MaterialApp(
    theme: buildAppTheme(),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('vi', 'VN'),
      Locale('en', 'US'),
    ],
    home: DrugInteractionWarningScreen(
      args: DrugInteractionWarningArgs(
        report: report,
        onAcknowledge: onAcknowledge,
        onConsultDoctor: onConsultDoctor,
      ),
    ),
  );
}

void main() {
  group('Task 4.02 · Mobile Drug Interaction Warning Screen & Mandatory Disclaimer', () {
    // -------------------------------------------------------------------------
    // Test 1: Mandatory Disclaimer xuất hiện trên 100% màn cảnh báo ở cả 3 trạng thái
    // -------------------------------------------------------------------------
    testWidgets(
      'Test 1: MandatoryDisclaimerCard xuất hiện trên màn hình trong cả 3 trạng thái và không có nút đóng',
      (tester) async {
        // 1.1 Kiểm tra trạng thái hasInteractions
        final reportHasInteractions = DrugInteractionReport(
          status: InteractionStatus.hasInteractions,
          pairs: [
            const DrugInteractionPair(
              firstDrugName: 'Aspirin',
              secondDrugName: 'Warfarin',
              severity: InteractionSeverity.contraindicated,
              description: 'Tăng nguy cơ xuất huyết tiêu hóa nghiêm trọng.',
              recommendation: 'Không dùng chung.',
            ),
          ],
        );

        await tester.pumpWidget(_buildTestApp(report: reportHasInteractions));
        await tester.pumpAndSettle();

        expect(find.byType(MandatoryDisclaimerCard), findsOneWidget);
        expect(
          find.text(
            'Lưu ý: Thông tin cảnh báo tương tác thuốc chỉ mang tính chất tham khảo, '
            'không thay thế cho chỉ định hoặc tư vấn chuyên môn của bác sĩ/dược sĩ.',
          ),
          findsOneWidget,
        );
        // Không có bất kỳ nút Close hay nút tắt (X) nào trong Disclaimer Card
        expect(
          find.descendant(
            of: find.byType(MandatoryDisclaimerCard),
            matching: find.byType(IconButton),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(MandatoryDisclaimerCard),
            matching: find.byIcon(Icons.close),
          ),
          findsNothing,
        );

        // 1.2 Kiểm tra trạng thái noKnownInteractions
        final reportNoInteractions = DrugInteractionReport(
          status: InteractionStatus.noKnownInteractions,
        );

        await tester.pumpWidget(_buildTestApp(report: reportNoInteractions));
        await tester.pumpAndSettle();

        expect(find.byType(MandatoryDisclaimerCard), findsOneWidget);
        expect(
          find.text(
            'Lưu ý: Thông tin cảnh báo tương tác thuốc chỉ mang tính chất tham khảo, '
            'không thay thế cho chỉ định hoặc tư vấn chuyên môn của bác sĩ/dược sĩ.',
          ),
          findsOneWidget,
        );

        // 1.3 Kiểm tra trạng thái insufficientData
        final reportInsufficientData = DrugInteractionReport(
          status: InteractionStatus.insufficientData,
          insufficientDataMedications: ['Thuốc đông y gia truyền'],
        );

        await tester.pumpWidget(_buildTestApp(report: reportInsufficientData));
        await tester.pumpAndSettle();

        expect(find.byType(MandatoryDisclaimerCard), findsOneWidget);
        expect(
          find.text(
            'Lưu ý: Thông tin cảnh báo tương tác thuốc chỉ mang tính chất tham khảo, '
            'không thay thế cho chỉ định hoặc tư vấn chuyên môn của bác sĩ/dược sĩ.',
          ),
          findsOneWidget,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Test 2: Trạng thái hasInteractions hiển thị đầy đủ tất cả các cặp xung đột
    // -------------------------------------------------------------------------
    testWidgets(
      'Test 2: Trạng thái hasInteractions hiển thị đầy đủ tất cả các cặp thuốc xung đột và mức độ nghiêm trọng',
      (tester) async {
        final pairs = [
          const DrugInteractionPair(
            firstDrugName: 'Clopidogrel 75mg',
            secondDrugName: 'Omeprazole 20mg',
            severity: InteractionSeverity.severe,
            description: 'Omeprazole làm giảm hoạt hóa Clopidogrel, giảm tác dụng chống kết tập tiểu cầu.',
            recommendation: 'Cân nhắc chuyển sang dùng Pantoprazole để tránh tương tác.',
            referenceSource: 'Dược thư Quốc gia Việt Nam 2022',
          ),
          const DrugInteractionPair(
            firstDrugName: 'Metformin 500mg',
            secondDrugName: 'Cimetidine 400mg',
            severity: InteractionSeverity.moderate,
            description: 'Cimetidine làm giảm thanh thải thận của Metformin, tăng nguy cơ nhiễm toan lactic.',
            recommendation: 'Theo dõi đường huyết và chức năng thận khi dùng phối hợp.',
          ),
          const DrugInteractionPair(
            firstDrugName: 'Paracetamol 500mg',
            secondDrugName: 'Isoniazid 150mg',
            severity: InteractionSeverity.mild,
            description: 'Tăng nhẹ độc tính trên gan khi dùng liều cao kéo dài.',
          ),
        ];

        final report = DrugInteractionReport(
          status: InteractionStatus.hasInteractions,
          pairs: pairs,
        );

        bool acknowledged = false;
        bool consultedDoctor = false;

        await tester.pumpWidget(
          _buildTestApp(
            report: report,
            onAcknowledge: () => acknowledged = true,
            onConsultDoctor: () => consultedDoctor = true,
          ),
        );
        await tester.pumpAndSettle();

        // Banner thông báo tổng số tương tác
        expect(find.textContaining('Phát hiện 3 tương tác thuốc'), findsOneWidget);

        // Hiển thị đầy đủ tất cả 3 thẻ InteractionPairCard (không dừng ở cặp đầu tiên)
        expect(find.byType(InteractionPairCard), findsNWidgets(3));

        // Kiểm tra tên các cặp thuốc
        expect(find.textContaining('Clopidogrel 75mg'), findsOneWidget);
        expect(find.textContaining('Omeprazole 20mg'), findsOneWidget);
        expect(find.textContaining('Metformin 500mg'), findsOneWidget);
        expect(find.textContaining('Cimetidine 400mg'), findsOneWidget);
        expect(find.textContaining('Paracetamol 500mg'), findsOneWidget);
        expect(find.textContaining('Isoniazid 150mg'), findsOneWidget);

        // Kiểm tra badges mức độ nghiêm trọng
        expect(find.text('Nghiêm trọng'), findsOneWidget);
        expect(find.text('Trung bình'), findsOneWidget);
        expect(find.text('Nhẹ'), findsOneWidget);

        // Kiểm tra các nút hành động
        final consultBtn = find.byKey(const Key('interaction_consult_doctor_button'));
        expect(consultBtn, findsOneWidget);
        await tester.tap(consultBtn);
        expect(consultedDoctor, isTrue);

        final ackBtn = find.byKey(const Key('interaction_acknowledge_button'));
        expect(ackBtn, findsOneWidget);
        await tester.tap(ackBtn);
        expect(acknowledged, isTrue);
      },
    );

    // -------------------------------------------------------------------------
    // Test 3: Trạng thái noKnownInteractions hiển thị đúng câu chữ và KHÔNG có từ "an toàn"
    // -------------------------------------------------------------------------
    testWidgets(
      'Test 3: noKnownInteractions hiển thị câu chữ bắt buộc và tuyệt đối KHÔNG chứa từ "an toàn"',
      (tester) async {
        final report = DrugInteractionReport(
          status: InteractionStatus.noKnownInteractions,
        );

        await tester.pumpWidget(_buildTestApp(report: report));
        await tester.pumpAndSettle();

        // 3.1 Bắt buộc hiển thị câu chữ chính xác
        expect(
          find.text('Không tìm thấy tương tác đã biết trong cơ sở dữ liệu hiện tại'),
          findsOneWidget,
        );

        // 3.2 BẤT BIẾN CD06: Tuyệt đối KHÔNG chứa từ "an toàn" (safe) trong toàn bộ widget tree
        final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final textWidget in allTextWidgets) {
          final content = textWidget.data?.toLowerCase() ?? '';
          expect(
            content.contains('an toàn'),
            isFalse,
            reason: 'Phát hiện từ "an toàn" vi phạm bất biến CD06 trong text: "${textWidget.data}"',
          );
          expect(
            content.contains('safe'),
            isFalse,
            reason: 'Phát hiện từ "safe" vi phạm bất biến CD06 trong text: "${textWidget.data}"',
          );
        }
      },
    );

    // -------------------------------------------------------------------------
    // Test 4: Trạng thái insufficientData hiển thị thông báo khuyến cáo hỏi bác sĩ
    // -------------------------------------------------------------------------
    testWidgets(
      'Test 4: insufficientData hiển thị thông báo khuyến cáo hỏi ý kiến bác sĩ/dược sĩ',
      (tester) async {
        final report = DrugInteractionReport(
          status: InteractionStatus.insufficientData,
          insufficientDataMedications: [
            'Thuốc bổ gan Boganic',
            'Cao ích mẫu',
          ],
        );

        await tester.pumpWidget(_buildTestApp(report: report));
        await tester.pumpAndSettle();

        // 4.1 Bắt buộc hiển thị câu chữ chính xác
        expect(
          find.text(
            'Một số thuốc chưa có dữ liệu hoạt chất để kiểm tra tương tác, '
            'vui lòng tham khảo ý kiến bác sĩ hoặc dược sĩ.',
          ),
          findsOneWidget,
        );

        // 4.2 Hiển thị danh sách các thuốc chưa có dữ liệu hoạt chất
        expect(find.text('Thuốc bổ gan Boganic'), findsOneWidget);
        expect(find.text('Cao ích mẫu'), findsOneWidget);

        // 4.3 Nút tiếp tục hoạt động bình thường
        expect(find.byKey(const Key('interaction_acknowledge_button')), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // Test 5: Điều hướng qua Route AppRoutes.interactionWarning
    // -------------------------------------------------------------------------
    testWidgets(
      'Test 5: Đăng ký route AppRoutes.interactionWarning hoạt động chính xác với router',
      (tester) async {
        final report = DrugInteractionReport(
          status: InteractionStatus.noKnownInteractions,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            onGenerateRoute: onGenerateRoute,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.interactionWarning,
                          arguments: report,
                        );
                      },
                      child: const Text('Open Warning Screen'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Warning Screen'));
        await tester.pumpAndSettle();

        expect(find.byType(DrugInteractionWarningScreen), findsOneWidget);
        expect(
          find.text('Không tìm thấy tương tác đã biết trong cơ sở dữ liệu hiện tại'),
          findsOneWidget,
        );
      },
    );
  });
}
