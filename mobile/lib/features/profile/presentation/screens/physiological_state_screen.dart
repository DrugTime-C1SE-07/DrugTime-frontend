import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';
import '../../domain/repositories/health_setup_repository.dart';
import '../state/health_setup_controller.dart';
import '../state/health_setup_status_controller.dart';
import '../widgets/health_profile_ui.dart';

/// Physiological state (N10, AC13b): pregnancy and breastfeeding are physiological states,
/// not chronic diseases, so they have their own screen. Pick any that apply, or "Không";
/// each choice is saved on its own (explicit "Không" is stored, Q6).
class PhysiologicalStateScreen extends StatefulWidget {
  const PhysiologicalStateScreen({super.key, required this.repository});
  final HealthSetupRepository? repository;

  @override
  State<PhysiologicalStateScreen> createState() =>
      _PhysiologicalStateScreenState();
}

class _PhysiologicalStateScreenState extends State<PhysiologicalStateScreen> {
  HealthSetupStatusController? _status;
  late final HealthSetupController _setup = HealthSetupController(
      widget.repository,
      onSaved: (saved) => _status?.apply(saved));
  final _mascot = MascotController();
  late final _reactions = MascotReactions(_mascot);
  bool _again = false;
  Future<void>? _draining;
  HealthSaveStatus _saveStatus = HealthSaveStatus.idle;

  @override
  void initState() {
    super.initState();
    _mascot.play(MascotMood.wave);
    _setup.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _status = HealthSetupStatusScope.read(context);
  }

  @override
  void dispose() {
    _reactions.dispose();
    _mascot.dispose();
    final pending = _draining;
    if (pending == null) {
      _setup.dispose();
    } else {
      unawaited(pending.whenComplete(_setup.dispose));
    }
    super.dispose();
  }

  /// Saves right away; a tap during a save is sent once that one finishes.
  void _changed() {
    final draft = _setup.physiologicalDraft;
    if (draft.ids.isNotEmpty) {
      _reactions.react(MascotMood.cradle, hold: const Duration(seconds: 4));
    } else if (draft.noneKnown) {
      _reactions.react(MascotMood.celebrate);
    }
    if (!draft.canContinue) {
      _again = false;
      setState(() => _saveStatus = HealthSaveStatus.unsaved);
      return;
    }
    if (_saveStatus != HealthSaveStatus.idle) {
      setState(() => _saveStatus = HealthSaveStatus.idle);
    }
    _again = true;
    _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    while (_again) {
      _again = false;
      final result = await _setup.saveStep(HealthSetupStepKind.physiological);
      if (result != HealthSetupSaveResult.failed) continue;
      _again = false;
      if (!mounted) return;
      setState(() => _saveStatus = HealthSaveStatus.failed);
      _reactions.react(MascotMood.concerned);
      if (_setup.conflict) {
        await _setup.load();
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: const Text('Chưa lưu được thay đổi.'),
            action: SnackBarAction(label: 'Thử lại', onPressed: _changed)));
    }
  }

  void _toggle(int id) {
    setState(() => _setup.physiologicalDraft.toggle(id));
    _changed();
  }

  void _toggleNone() {
    setState(_setup.physiologicalDraft.toggleNone);
    _changed();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: HealthProfileStyle.canvas,
        appBar: ProfileFlowHeader('Tình trạng sinh lý',
            titleScale: MediaQuery.textScalerOf(context).scale(18) / 18,
            backgroundColor: HealthProfileStyle.canvas),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _setup,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                HealthHeroCard(
                  mascot: _mascot,
                  title: 'Không phải bệnh đâu nhé',
                  subtitle:
                      'Mang thai và cho con bú là tình trạng sinh lý. Dumi dùng để cảnh báo thuốc không phù hợp.',
                  status: _saveStatus,
                  onRetry: _changed,
                ),
                const SizedBox(height: 16),
                ..._body(),
              ],
            ),
          ),
        ),
      );

  List<Widget> _body() {
    if (_setup.loading && _setup.snapshot == null) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_setup.loadFailed || widget.repository == null) {
      return [
        HealthStateMessage(
          text: 'Dumi chưa tải được thông tin.',
          action: widget.repository == null ? null : 'Thử lại',
          onAction: _setup.load,
        ),
      ];
    }
    if (_setup.snapshot == null) return const [];
    final draft = _setup.physiologicalDraft;
    final options = _setup.physiologicalOptions;
    return [
      Semantics(
        header: true,
        child: Text('Hiện tại bạn có đang…',
            style: AppTextStyles.heading.copyWith(color: AppColors.ink)),
      ),
      const SizedBox(height: 4),
      Text('Chọn tất cả mục phù hợp. Có thể đổi bất cứ lúc nào.',
          style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
      const SizedBox(height: 12),
      if (options.isEmpty)
        const HealthStateMessage(text: 'Danh mục chưa có mục nào.'),
      for (final option in options) ...[
        _OptionCard(
          key: Key('physiological-option-${option.id}'),
          label: option.name,
          icon: option.name.toLowerCase().contains('bú')
              ? Icons.child_friendly_outlined
              : Icons.pregnant_woman,
          selected: draft.ids.contains(option.id),
          onTap: () => _toggle(option.id),
        ),
        const SizedBox(height: 12),
      ],
      _OptionCard(
        key: const Key('physiological-none'),
        label: 'Không',
        caption: 'Không mang thai, không cho con bú',
        icon: Icons.do_not_disturb_on_outlined,
        selected: draft.noneKnown,
        onTap: _toggleNone,
      ),
      const SizedBox(height: 16),
      Text(
          'Lựa chọn được lưu ngay. Thông tin chỉ dùng để kiểm tra an toàn thuốc.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted)),
    ];
  }
}

/// Large selectable card (multi-select for states, exclusive "Không").
class _OptionCard extends StatefulWidget {
  const _OptionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.caption,
  });
  final String label;
  final String? caption;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.caption == null
          ? widget.label
          : '${widget.label}, ${widget.caption}',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? AppColors.brandTint : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppColors.brand : AppColors.border,
                  width: selected ? 1.6 : 1),
              boxShadow: selected ? null : AppShadows.cardElevation,
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: selected ? Colors.white : HealthProfileStyle.pink,
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(widget.icon,
                    color: selected
                        ? AppColors.brand
                        : HealthProfileStyle.pinkInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label, style: AppTextStyles.bodyStrong),
                      if (widget.caption != null)
                        Text(widget.caption!,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.inkMuted)),
                    ]),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  key: ValueKey(selected),
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.brand : AppColors.inkMuted,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
