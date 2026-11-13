import 'package:flutter/widgets.dart';

import '../../domain/entities/drug_food_interaction.dart';
import '../../domain/repositories/food_interaction_repository.dart';

/// Các trạng thái UI của tính năng kiểm tra tương tác thuốc - thức ăn (AC5).
sealed class FoodWarningState {
  const FoodWarningState();
}

class FoodWarningInitial extends FoodWarningState {
  const FoodWarningInitial();
}

class FoodWarningLoading extends FoodWarningState {
  const FoodWarningLoading();
}

class FoodWarningEmpty extends FoodWarningState {
  const FoodWarningEmpty([
    this.message = 'Đã kiểm tra, không phát hiện lưu ý tương tác với thức ăn/đồ uống.',
  ]);
  final String message;
}

class FoodWarningError extends FoodWarningState {
  const FoodWarningError(this.message);
  final String message;
}

class FoodWarningSuccess extends FoodWarningState {
  const FoodWarningSuccess(this.result);
  final DrugFoodInteractionResult result;
}

/// Controller quản lý luồng kiểm tra và 4 trạng thái giao diện (AC5).
class FoodWarningController extends ChangeNotifier {
  FoodWarningController(this._repository);

  final FoodInteractionRepository _repository;

  FoodWarningState _state = const FoodWarningInitial();

  FoodWarningState get state => _state;
  bool get isLoading => _state is FoodWarningLoading;
  DrugFoodInteractionResult? get result => switch (_state) {
        FoodWarningSuccess(:final result) => result,
        _ => null,
      };

  Future<DrugFoodInteractionResult> checkFoodInteractions({
    required String patientId,
    String? medicationName,
    String? activeIngredient,
    int? catalogId,
    List<int>? medicationIds,
  }) async {
    _state = const FoodWarningLoading();
    notifyListeners();

    try {
      final res = await _repository.checkFoodInteractions(
        patientId: patientId,
        medicationName: medicationName,
        activeIngredient: activeIngredient,
        catalogId: catalogId,
        medicationIds: medicationIds,
      );

      if (res.hasWarnings) {
        _state = FoodWarningSuccess(res);
      } else {
        _state = const FoodWarningEmpty();
      }
      notifyListeners();
      return res;
    } catch (e) {
      _state = FoodWarningError(
        'Không thể kiểm tra tương tác thuốc - thức ăn lúc này: $e',
      );
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    _state = const FoodWarningInitial();
    notifyListeners();
  }
}
