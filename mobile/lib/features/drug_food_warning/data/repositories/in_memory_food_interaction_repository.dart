library;

import '../../domain/entities/drug_food_interaction.dart';
import '../../domain/repositories/food_interaction_repository.dart';

/// Repository in-memory chứa dữ liệu chuẩn của 4 ca tương tác kinh điển (Task 4.06, AC2).
class InMemoryFoodInteractionRepository implements FoodInteractionRepository {
  InMemoryFoodInteractionRepository({
    this.stubResult,
    this.onCheck,
  });

  DrugFoodInteractionResult? stubResult;
  Future<DrugFoodInteractionResult> Function({
    required String patientId,
    String? medicationName,
    String? activeIngredient,
    int? catalogId,
    List<int>? medicationIds,
  })? onCheck;

  static const FoodWarningItem atorvastatinGrapefruit = FoodWarningItem(
    id: 'df-atorvastatin-grapefruit',
    medicationName: 'Atorvastatin 20mg',
    activeIngredient: 'Atorvastatin',
    foodName: 'Bưởi chùm & Nước ép bưởi chùm (Grapefruit)',
    foodCategory: 'Trái cây có múi',
    severity: FoodInteractionSeverity.severe,
    mechanismAndRisk:
        'Furanocoumarin trong bưởi chùm ức chế enzyme CYP3A4 ở ruột non, '
        'làm tăng nồng độ Atorvastatin trong huyết tương lên 2-3 lần, '
        'tăng đáng kể nguy cơ độc cơ (tiêu cơ vân cấp, rhabdomyolysis) và tổn thương gan.',
    recommendation:
        'Tránh ăn bưởi chùm hoặc uống nước ép bưởi chùm trong suốt quá trình dùng thuốc. '
        'Không thể khắc phục chỉ bằng việc giãn cách giờ uống thuốc.',
    timingAdvice: 'Tránh hoàn toàn bưởi chùm',
    source: 'Dược thư Quốc gia Việt Nam 2022 & FDA Drug Safety Communication',
    catalogId: 101,
  );

  static const FoodWarningItem metforminAlcohol = FoodWarningItem(
    id: 'df-metformin-alcohol',
    medicationName: 'Metformin 500mg',
    activeIngredient: 'Metformin',
    foodName: 'Rượu bia & Đồ uống có cồn (Ethanol)',
    foodCategory: 'Đồ uống có cồn',
    severity: FoodInteractionSeverity.contraindicated,
    mechanismAndRisk:
        'Cồn ức chế quá trình tân tạo glucose tại gan, đồng thời làm tăng nồng độ '
        'acid lactic trong máu. Sự kết hợp giữa Metformin và cồn làm tăng nguy cơ '
        'nhiễm toan acid lactic (Lactic Acidosis) cấp tính, có thể đe dọa tính mạng.',
    recommendation:
        'Tuyệt đối không uống rượu bia khi đang điều trị bằng Metformin. '
        'Nếu lỡ uống rượu bia, cần theo dõi sát các dấu hiệu mệt mỏi, khó thở, '
        'đau bụng dữ dội và báo ngay cơ sở y tế.',
    timingAdvice: 'Kiêng tuyệt đối cồn',
    source: 'Dược thư Quốc gia Việt Nam 2022 & Hướng dẫn ADA',
    catalogId: 102,
  );

  static const FoodWarningItem ciprofloxacinDairy = FoodWarningItem(
    id: 'df-ciprofloxacin-dairy',
    medicationName: 'Ciprofloxacin 500mg',
    activeIngredient: 'Ciprofloxacin',
    foodName: 'Sữa & Chế phẩm giàu Canxi (Sữa tươi, sữa chua, phô mai)',
    foodCategory: 'Sữa & Chế phẩm canxi',
    severity: FoodInteractionSeverity.moderate,
    mechanismAndRisk:
        'Các ion Canxi (Ca2+) đa hóa trị trong sữa tạo phức chelate không tan '
        'với phân tử Ciprofloxacin trong lòng ruột, làm giảm hấp thu kháng sinh từ '
        '40% đến 70%, dẫn đến nguy cơ thất bại điều trị nhiễm khuẩn.',
    recommendation:
        'Uống Ciprofloxacin cách xa bữa ăn có sữa hoặc chế phẩm canxi ít nhất '
        '2 giờ trước hoặc 4 đến 6 giờ sau khi dùng sản phẩm từ sữa.',
    timingAdvice: 'Uống cách xa sữa tối thiểu 2 giờ',
    source:
        'Dược thư Quốc gia Việt Nam 2022 & Stanford Health Care Antibiotic Guidelines',
    catalogId: 103,
  );

  static const FoodWarningItem warfarinVitaminK = FoodWarningItem(
    id: 'df-warfarin-vitamink',
    medicationName: 'Warfarin 5mg',
    activeIngredient: 'Warfarin',
    foodName: 'Rau lá xanh đậm giàu Vitamin K (Rau chân vịt, cải xoăn, súp lơ xanh)',
    foodCategory: 'Rau xanh giàu Vitamin K',
    severity: FoodInteractionSeverity.minor,
    mechanismAndRisk:
        'Vitamin K là cofactor cần thiết để tổng hợp các yếu tố đông máu tại gan, '
        'trực tiếp đối kháng cơ chế chống đông của Warfarin. Lượng Vitamin K nạp vào dao động '
        'bất thường làm thay đổi chỉ số INR, tăng nguy cơ huyết khối hoặc xuất huyết.',
    recommendation:
        'Không cần kiêng hoàn toàn rau xanh, nhưng cần duy trì lượng ăn ổn định hàng ngày; '
        'tránh thay đổi đột ngột chế độ ăn; kiểm tra định kỳ chỉ số INR.',
    timingAdvice: 'Duy trì khẩu phần ổn định mỗi ngày',
    source:
        'Dược thư Quốc gia Việt Nam 2022 & Chest Guidelines on Antithrombotic Therapy',
    catalogId: 104,
  );

  static const List<FoodWarningItem> allClassicItems = [
    atorvastatinGrapefruit,
    metforminAlcohol,
    ciprofloxacinDairy,
    warfarinVitaminK,
  ];

  @override
  Future<DrugFoodInteractionResult> checkFoodInteractions({
    required String patientId,
    String? medicationName,
    String? activeIngredient,
    int? catalogId,
    List<int>? medicationIds,
  }) async {
    if (onCheck != null) {
      return onCheck!(
        patientId: patientId,
        medicationName: medicationName,
        activeIngredient: activeIngredient,
        catalogId: catalogId,
        medicationIds: medicationIds,
      );
    }
    if (stubResult != null) {
      return stubResult!;
    }

    final query = (medicationName ?? '').toLowerCase();
    final ingredient = (activeIngredient ?? '').toLowerCase();

    final matched = <FoodWarningItem>[];

    for (final item in allClassicItems) {
      final itemDrug = item.medicationName.toLowerCase();
      final itemIng = item.activeIngredient.toLowerCase();

      bool match = false;
      if (query.isNotEmpty &&
          (query.contains(itemIng) || itemDrug.contains(query))) {
        match = true;
      } else if (ingredient.isNotEmpty &&
          (ingredient.contains(itemIng) || itemIng.contains(ingredient))) {
        match = true;
      } else if (query.isEmpty && ingredient.isEmpty) {
        if (catalogId != null && item.catalogId == catalogId) {
          match = true;
        } else if (medicationIds != null &&
            item.catalogId != null &&
            medicationIds.contains(item.catalogId)) {
          match = true;
        }
      }

      if (match && !matched.contains(item)) {
        matched.add(item);
      }
    }

    if (matched.isEmpty) {
      return const DrugFoodInteractionResult(
        status: FoodInteractionStatus.noneFound,
        warnings: [],
      );
    }

    return DrugFoodInteractionResult(
      status: FoodInteractionStatus.found,
      warnings: matched,
    );
  }
}
