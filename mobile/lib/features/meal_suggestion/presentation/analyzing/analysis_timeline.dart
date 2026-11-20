import '../../domain/entities/meal_suggestion.dart';
import '../state/meal_plan_controller.dart';

/// Bước tiếp theo của màn chờ.
enum AnalysisStep {
  /// Còn bữa đang chạy, hoặc chưa đủ thời gian hiện tối thiểu.
  wait,

  /// Đã có kết quả nhưng ảnh món của bữa sắp hiển thị chưa tải xong: giữ màn chờ
  /// (adhoc-20261120-meal-image-loading, AC3).
  preparingImages,

  /// Đủ kết quả (ít nhất 1 bữa thành công): chạy chuỗi kết thúc "siêu tân tinh".
  finale,

  /// Giảm chuyển động: bỏ chuỗi kết thúc, sang kết quả ngay.
  done,

  /// Mọi bữa đều lỗi: không chạy chuỗi kết thúc, hiện lỗi + "Thử lại".
  failed,
}

/// Logic thời gian của màn chờ, tách khỏi giao diện để kiểm thử (AC4, AC5, AC14b, AC15).
abstract final class AnalysisTimeline {
  /// Màn chờ hiện tối thiểu chừng này để người dùng kịp thấy Dumi "nấu".
  static const minShow = Duration(milliseconds: 2500);

  /// Tổng chuỗi kết thúc (hút vào → lấy đà → bùng sáng 1 lần → pháo hoa → lộ đĩa món).
  static const finale = Duration(milliseconds: 1600);

  /// Nghỉ ngắn sau chuỗi kết thúc trước khi chuyển màn.
  static const settle = Duration(milliseconds: 280);

  static AnalysisStep next({
    required Map<MealType, MealTabStatus> statuses,
    required bool minShowPassed,
    required bool reduceMotion,
    bool imagesReady = true,
  }) {
    final running = statuses.values
        .any((s) => s == MealTabStatus.loading || s == MealTabStatus.idle);
    if (running || !minShowPassed) return AnalysisStep.wait;
    if (statuses.values.every((s) => s == MealTabStatus.error)) {
      return AnalysisStep.failed;
    }
    if (!imagesReady) return AnalysisStep.preparingImages;
    return reduceMotion ? AnalysisStep.done : AnalysisStep.finale;
  }

  /// Bữa mở sẵn ở màn kết quả: bữa sắp tới theo giờ VN; bữa đó lỗi thì bữa thành công gần nhất (AC6).
  static MealType revealMeal(
      Map<MealType, MealTabStatus> statuses, MealType upcoming) {
    if (statuses[upcoming] == MealTabStatus.data) return upcoming;
    // Gần nhất trước; hòa thì ưu tiên bữa sau (sắp tới) hơn bữa đã qua.
    int distance(MealType t) =>
        (t.index - upcoming.index).abs() * 2 +
        (t.index < upcoming.index ? 1 : 0);
    final order = [...MealType.values]
      ..sort((a, b) => distance(a).compareTo(distance(b)));
    return order.firstWhere((t) => statuses[t] == MealTabStatus.data,
        orElse: () => upcoming);
  }
}
