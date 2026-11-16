import 'package:drugtime_mobile/features/drug_food_warning/data/repositories/in_memory_food_interaction_repository.dart';
import 'package:drugtime_mobile/features/drug_food_warning/domain/entities/drug_food_interaction.dart';
import 'package:drugtime_mobile/features/drug_food_warning/presentation/widgets/food_warning_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => child,
            ),
            child: const Text('Open Dialog'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FoodWarningDialog Widget Tests', () {
    testWidgets('Renders collapsed cards by default with down arrow', (tester) async {
      const result = DrugFoodInteractionResult(
        status: FoodInteractionStatus.found,
        warnings: [
          InMemoryFoodInteractionRepository.atorvastatinGrapefruit,
        ],
      );

      await tester.pumpWidget(_buildTestApp(const FoodWarningDialog(result: result)));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Header is rendered
      expect(find.text('TƯƠNG TÁC THỨC ĂN NGUY CƠ CAO'), findsOneWidget);
      expect(find.text('Phát hiện 1 lưu ý tương tác thức ăn:'), findsOneWidget);

      // Card collapsed state
      expect(find.text('MỨC 2'), findsOneWidget);
      expect(find.text('Nghiêm trọng · Trái cây có múi'), findsOneWidget);
      expect(find.textContaining('Atorvastatin 20mg'), findsOneWidget);
      expect(find.textContaining('Bưởi chùm'), findsOneWidget);

      // Down arrow is present
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

      // Details are NOT shown when collapsed
      expect(find.text('• Nguy cơ:'), findsNothing);
      expect(find.text('• Khuyến nghị:'), findsNothing);

      // Disclaimer is always visible
      expect(find.text(nfr03Disclaimer), findsOneWidget);
    });

    testWidgets('Tapping card expands details with 92px label alignment and up arrow', (tester) async {
      const result = DrugFoodInteractionResult(
        status: FoodInteractionStatus.found,
        warnings: [
          InMemoryFoodInteractionRepository.atorvastatinGrapefruit,
        ],
      );

      await tester.pumpWidget(_buildTestApp(const FoodWarningDialog(result: result)));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap on card to expand
      await tester.tap(find.byKey(const Key('food_warning_toggle_df-atorvastatin-grapefruit')));
      await tester.pumpAndSettle();

      // Now details are shown
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('• Nguy cơ:'), findsOneWidget);
      expect(find.text('• Khuyến nghị:'), findsOneWidget);
      expect(find.textContaining('CYP3A4'), findsOneWidget);
      expect(find.textContaining('Tránh ăn bưởi chùm'), findsOneWidget);
      expect(find.textContaining('Dược thư Quốc gia'), findsOneWidget);

      // Verify label width is 92px
      final labelContainers = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 92,
      );
      expect(labelContainers, findsNWidgets(2)); // Nguy cơ & Khuyến nghị

      // Tap again collapses
      await tester.tap(find.byKey(const Key('food_warning_toggle_df-atorvastatin-grapefruit')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('• Nguy cơ:'), findsNothing);
    });

    testWidgets('Level 1 Contraindicated shows red header and theme', (tester) async {
      const result = DrugFoodInteractionResult(
        status: FoodInteractionStatus.found,
        warnings: [
          InMemoryFoodInteractionRepository.metforminAlcohol,
        ],
      );

      await tester.pumpWidget(_buildTestApp(const FoodWarningDialog(result: result)));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('CẢNH BÁO CHỐNG CHỈ ĐỊNH THỰC PHẨM'), findsOneWidget);
      expect(find.text('MỨC 1'), findsOneWidget);
      expect(find.text('Chống chỉ định · Đồ uống có cồn'), findsOneWidget);
    });

    testWidgets('Displays insufficient data medications if present', (tester) async {
      const result = DrugFoodInteractionResult(
        status: FoodInteractionStatus.found,
        warnings: [
          InMemoryFoodInteractionRepository.ciprofloxacinDairy,
        ],
        insufficientDataMedications: ['Thuốc Đông Y Tự Kê'],
      );

      await tester.pumpWidget(_buildTestApp(const FoodWarningDialog(result: result)));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Thuốc chưa đủ dữ liệu hoạt chất để đối soát:'), findsOneWidget);
      expect(find.text('• Thuốc Đông Y Tự Kê'), findsOneWidget);
    });

    testWidgets('Clicking Quay lại chỉnh sửa pops false', (tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showFoodWarningDialog(
                    context,
                    const DrugFoodInteractionResult(
                      status: FoodInteractionStatus.found,
                      warnings: [InMemoryFoodInteractionRepository.warfarinVitaminK],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('food_warning_back_button')));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });

    testWidgets('Clicking Tôi đã hiểu và tiếp tục pops true', (tester) async {
      bool? dialogResult;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showFoodWarningDialog(
                    context,
                    const DrugFoodInteractionResult(
                      status: FoodInteractionStatus.found,
                      warnings: [InMemoryFoodInteractionRepository.warfarinVitaminK],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('food_warning_proceed_button')));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });
  });
}
