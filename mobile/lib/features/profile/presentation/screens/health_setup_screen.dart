import 'package:flutter/material.dart';

import '../../domain/repositories/health_setup_repository.dart';
import '../state/health_setup_controller.dart';
import '../state/health_setup_status_controller.dart';
import '../state/profile_controller.dart';
import '../widgets/health_setup_custom_sheet.dart';
import '../widgets/health_setup_form.dart';
import '../widgets/health_setup_motion.dart';
import 'health_setup_complete_screen.dart';

class HealthSetupScreen extends StatefulWidget {
  const HealthSetupScreen({
    super.key,
    required this.repository,
    this.onLeave,
    this.steps,
  });
  final HealthSetupRepository? repository;
  final VoidCallback? onLeave;

  /// Steps to ask, in order. Default: allergy → condition → physiological, without the
  /// physiological step for men (Q7). `[allergy]` alone is the Dumi AI declaration (N7): it
  /// saves and returns `true` without the summary screen.
  final List<HealthSetupStepKind>? steps;

  @override
  State<HealthSetupScreen> createState() => _HealthSetupScreenState();
}

class _HealthSetupScreenState extends State<HealthSetupScreen> {
  late final _controller = HealthSetupController(widget.repository,
      onSaved: (saved) => HealthSetupStatusScope.read(context)?.apply(saved));
  int _index = 0;
  String? _inputError;

  List<HealthSetupStepKind> get _steps {
    final given = widget.steps;
    if (given != null) return given;
    final male = context
            .dependOnInheritedWidgetOfExactType<ProfileScope>()
            ?.notifier
            ?.profile
            ?.isMale ??
        false;
    return [
      HealthSetupStepKind.allergy,
      HealthSetupStepKind.condition,
      if (!male) HealthSetupStepKind.physiological,
    ];
  }

  HealthSetupStepKind get _kind => _steps[_index];
  bool get _allergy => _kind == HealthSetupStepKind.allergy;
  bool get _single => _steps.length == 1;
  bool get _last => _index == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _leave() {
    widget.onLeave?.call();
    Navigator.pop(context, true);
  }

  void _back() {
    if (_controller.saved != null) {
      _leave();
      return;
    }
    if (_controller.saving) return;
    if (_index == 0) {
      Navigator.pop(context);
    } else {
      setState(() {
        _index--;
        _inputError = null;
      });
    }
  }

  Future<void> _advance({required bool include}) async {
    switch (_kind) {
      case HealthSetupStepKind.allergy:
        _controller.includeAllergies(include);
      case HealthSetupStepKind.condition:
        _controller.includeConditions(include);
      case HealthSetupStepKind.physiological:
        break;
    }
    if (!_last) {
      setState(() {
        _index++;
        _inputError = null;
      });
      return;
    }
    final result = await _controller.finish(
        includeConditions: false,
        includePhysiological:
            include && _kind == HealthSetupStepKind.physiological);
    if (!mounted) return;
    if (result == HealthSetupSaveResult.skipped) {
      _leave();
    } else if (result == HealthSetupSaveResult.saved && _single) {
      // Dumi AI: back to the meal flow, which continues (AC12).
      widget.onLeave?.call();
      Navigator.pop(context, true);
    }
  }

  Future<void> _showCustom() async {
    final value = await showHealthSetupCustomSheet(context, allergy: _allergy);
    if (!mounted || value == null) return;
    final accepted = _allergy
        ? _controller.allergyDraft.addCustom(value)
        : _controller.conditionDraft.addCustom(value);
    setState(() =>
        _inputError = accepted ? null : 'Mục đã có hoặc tên không hợp lệ.');
  }

  String? _warning() {
    if (_inputError != null) return _inputError;
    if (_controller.conflict) {
      final current = _controller.snapshot!;
      final conditions = healthSetupSummary(current.conditions,
          _controller.conditionOptions, 'Không có bệnh nền đã biết');
      final allergies = healthSetupSummary(current.allergies,
          _controller.allergenOptions, 'Không có dị ứng đã biết');
      return 'Hồ sơ đã thay đổi. Đang lưu: dị ứng – $allergies; bệnh nền – $conditions. '
          'Kiểm tra lựa chọn của bạn trước khi bấm Tiếp tục để lưu lại.';
    }
    if (_controller.saveFailed) return 'Chưa lưu được hồ sơ. Vui lòng thử lại.';
    return null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final saved = _controller.saved;
          return Theme(
            data: Theme.of(context).copyWith(
              textTheme:
                  Theme.of(context).textTheme.apply(fontFamily: 'WelcomeInter'),
            ),
            child: PopScope(
              canPop: saved == null && _index == 0 && !_controller.saving,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && !_controller.saving) _back();
              },
              child: HealthSetupAnimatedStep(
                child: saved != null && !_single
                    ? HealthSetupCompleteScreen(
                        key: const ValueKey('complete'),
                        snapshot: saved,
                        allergens: _controller.allergenOptions,
                        conditions: _controller.conditionOptions,
                        onHome: _leave)
                    : KeyedSubtree(key: const ValueKey('form'), child: _form()),
              ),
            ),
          );
        },
      );

  Widget _stepForm(String? warning) {
    void changed() => setState(() => _inputError = null);
    final step = _index + 1, of = _steps.length;
    return switch (_kind) {
      HealthSetupStepKind.allergy => HealthSetupForm(
          key: const ValueKey('allergies'),
          allergy: true,
          options: _controller.allergenOptions,
          draft: _controller.allergyDraft,
          warning: warning,
          step: step,
          of: of,
          onChanged: changed,
          onAdd: _showCustom),
      HealthSetupStepKind.condition => HealthSetupForm(
          key: const ValueKey('conditions'),
          allergy: false,
          // Chronic diseases only: pregnancy and breastfeeding have their own step (N10).
          options: _controller.chronicOptions,
          draft: _controller.conditionDraft,
          warning: warning,
          step: step,
          of: of,
          onChanged: changed,
          onAdd: _showCustom),
      HealthSetupStepKind.physiological => HealthSetupForm(
          key: const ValueKey('physiological'),
          allergy: false,
          physiological: true,
          options: _controller.physiologicalOptions,
          draft: _controller.physiologicalDraft,
          warning: warning,
          step: step,
          of: of,
          onChanged: changed,
          onAdd: () {}),
    };
  }

  Widget _form() {
    final ready = _controller.snapshot != null;
    final enabled = ready && !_controller.saving;
    final canContinue = enabled && _controller.draftOf(_kind).canContinue;
    final warning = _warning();
    return Scaffold(
      backgroundColor: healthSetupPaper,
      bottomNavigationBar: ready
          ? HealthSetupActionBar(
              label: 'Tiếp tục',
              saving: _controller.saving,
              onPressed: canContinue ? () => _advance(include: true) : null,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HealthSetupHeader(
              back: _controller.saving ? null : _back,
              skip: enabled ? () => _advance(include: false) : null,
            ),
            Expanded(
              child: _controller.loading
                  ? const Center(child: CircularProgressIndicator())
                  : _controller.loadFailed
                      ? Center(
                          child: Padding(
                          padding: const EdgeInsets.all(20),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('Chưa tải được hồ sơ sức khỏe.'),
                            TextButton(
                                onPressed: _controller.load,
                                child: const Text('Thử lại')),
                          ]),
                        ))
                      : AbsorbPointer(
                          absorbing: _controller.saving,
                          child: HealthSetupAnimatedStep(
                            direction: _index == 0 ? -1 : 1,
                            child: _stepForm(warning),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
