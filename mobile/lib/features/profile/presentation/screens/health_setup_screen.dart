import 'package:flutter/material.dart';

import '../../domain/repositories/health_setup_repository.dart';
import '../state/health_setup_controller.dart';
import '../widgets/health_setup_custom_sheet.dart';
import '../widgets/health_setup_form.dart';
import '../widgets/health_setup_motion.dart';
import 'health_setup_complete_screen.dart';

class HealthSetupScreen extends StatefulWidget {
  const HealthSetupScreen({
    super.key,
    required this.repository,
    this.onLeave,
  });
  final HealthSetupRepository? repository;
  final VoidCallback? onLeave;

  @override
  State<HealthSetupScreen> createState() => _HealthSetupScreenState();
}

class _HealthSetupScreenState extends State<HealthSetupScreen> {
  late final _controller = HealthSetupController(widget.repository);
  bool _allergy = true;
  String? _inputError;

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
    if (_allergy) {
      Navigator.pop(context);
    } else {
      setState(() {
        _allergy = true;
        _inputError = null;
      });
    }
  }

  Future<void> _advance({required bool include}) async {
    if (_allergy) {
      _controller.includeAllergies(include);
      setState(() {
        _allergy = false;
        _inputError = null;
      });
      return;
    }
    final result = await _controller.finish(includeConditions: include);
    if (mounted && result == HealthSetupSaveResult.skipped) {
      _leave();
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
              canPop: saved == null && _allergy && !_controller.saving,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && !_controller.saving) _back();
              },
              child: HealthSetupAnimatedStep(
                child: saved != null
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

  Widget _form() {
    final ready = _controller.snapshot != null;
    final enabled = ready && !_controller.saving;
    final canContinue = enabled &&
        (_allergy
            ? _controller.allergyDraft.canContinue
            : _controller.conditionDraft.canContinue);
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
                            direction: _allergy ? -1 : 1,
                            child: _allergy
                                ? HealthSetupForm(
                                    key: const ValueKey('allergies'),
                                    allergy: true,
                                    options: _controller.allergenOptions,
                                    draft: _controller.allergyDraft,
                                    warning: warning,
                                    onChanged: () =>
                                        setState(() => _inputError = null),
                                    onAdd: _showCustom)
                                : HealthSetupForm(
                                    key: const ValueKey('conditions'),
                                    allergy: false,
                                    options: _controller.conditionOptions,
                                    draft: _controller.conditionDraft,
                                    warning: warning,
                                    onChanged: () =>
                                        setState(() => _inputError = null),
                                    onAdd: _showCustom),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
