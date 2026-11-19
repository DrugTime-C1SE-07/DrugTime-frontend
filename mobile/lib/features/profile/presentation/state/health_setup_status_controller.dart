import 'package:flutter/widgets.dart';

import '../../domain/entities/health_setup.dart';
import '../../domain/repositories/health_setup_repository.dart';

/// Health-setup snapshot shared by Home (CTA), the health profile and the physiological
/// state screen.
///
/// This is profile data, not an authorization decision: every screen calls [reload] when it
/// opens or comes back into view, so a revoked consent or link shows on the next request
/// (invariant 4). [clear] drops the data on consent loss, account switch and logout.
class HealthSetupStatusController extends ChangeNotifier {
  HealthSetupStatusController(this._repository);

  final HealthSetupRepository? _repository;
  HealthSetupSnapshot? snapshot;
  List<HealthSetupOption<int>> conditionOptions = const [];
  List<HealthSetupOption<String>> allergenOptions = const [];
  bool loading = false;
  bool failed = false;
  int _generation = 0;
  bool _disposed = false;

  bool get available => _repository != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Reads the snapshot; the catalogs are read once per session (they are not patient data).
  Future<void> reload() async {
    final repo = _repository;
    if (repo == null) return;
    final generation = ++_generation;
    loading = true;
    failed = false;
    _notify();
    try {
      final needsCatalog = conditionOptions.isEmpty || allergenOptions.isEmpty;
      final setup = repo.read();
      final conditions =
          needsCatalog ? repo.conditions() : Future.value(conditionOptions);
      final allergens =
          needsCatalog ? repo.allergens() : Future.value(allergenOptions);
      final (fresh, conditionList, allergenList) =
          await (setup, conditions, allergens).wait;
      if (generation != _generation || _disposed) return;
      snapshot = fresh;
      conditionOptions = conditionList;
      allergenOptions = allergenList;
    } catch (_) {
      // Shown as a retryable state; the stale snapshot is dropped so no CTA is decided on it.
      if (generation != _generation || _disposed) return;
      snapshot = null;
      failed = true;
    } finally {
      if (generation == _generation && !_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  /// A save elsewhere returned the new snapshot; use it without another read.
  void apply(HealthSetupSnapshot saved) {
    _generation++;
    snapshot = saved;
    failed = false;
    loading = false;
    _notify();
  }

  void clear() {
    _generation++;
    snapshot = null;
    conditionOptions = const [];
    allergenOptions = const [];
    loading = false;
    failed = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class HealthSetupStatusScope
    extends InheritedNotifier<HealthSetupStatusController> {
  const HealthSetupStatusScope(
      {super.key,
      required HealthSetupStatusController controller,
      required super.child})
      : super(notifier: controller);

  static HealthSetupStatusController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<HealthSetupStatusScope>()
      ?.notifier;

  static HealthSetupStatusController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HealthSetupStatusScope>()?.notifier;
}
