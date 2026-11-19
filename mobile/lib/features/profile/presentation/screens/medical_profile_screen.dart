import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';
import '../../domain/repositories/health_setup_repository.dart';
import '../state/health_setup_controller.dart';
import '../state/health_setup_status_controller.dart';
import '../state/profile_controller.dart';
import '../widgets/health_profile_ui.dart';
import '../widgets/health_setup_custom_sheet.dart';
import '../widgets/health_setup_form.dart';
import '../widgets/profile_notices.dart';

/// Health profile (N2, N8, N10, N11): allergies and chronic diseases on one friendly page,
/// physiological states (pregnancy, breastfeeding) on their own screen. Every change is saved
/// on its own through `/profile/health-setup` (allergies, "no chronic disease", physiological
/// state) or the condition links (diseases with subtype/stage), and the medic mascot reacts.
class MedicalProfileScreen extends StatefulWidget {
  const MedicalProfileScreen({super.key, this.repository});
  final HealthSetupRepository? repository;

  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {
  // Kept from the first build so a save that finishes after the screen closes can still
  // update Home (no `context` lookups once unmounted).
  HealthSetupStatusController? _status;
  late final HealthSetupController _setup = HealthSetupController(
      widget.repository,
      onSaved: (saved) => _status?.apply(saved));
  final _mascot = MascotController();
  late final _reactions = MascotReactions(_mascot);
  final _queue = <HealthSetupStepKind>{};
  Future<void>? _draining;
  HealthSaveStatus _saveStatus = HealthSaveStatus.idle;

  @override
  void initState() {
    super.initState();
    _mascot.play(MascotMood.wave);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ProfileScope.read(context).load();
      _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _status = HealthSetupStatusScope.read(context);
  }

  Future<void> _load() async {
    if (widget.repository == null) return;
    await _setup.load();
    if (!mounted) return;
    if (_setup.loadFailed) _reactions.react(MascotMood.concerned);
  }

  @override
  void dispose() {
    _reactions.dispose();
    _mascot.dispose();
    // Leaving right after a tap must not lose it: finish queued saves, then release.
    final pending = _draining;
    if (pending == null) {
      _setup.dispose();
    } else {
      unawaited(pending.whenComplete(_setup.dispose));
    }
    super.dispose();
  }

  /// Saves [kind] right away (feedback 20/11: "realtime"). Taps during a save are queued
  /// and sent one after another with the fresh revision, so they never conflict.
  void _autosave(HealthSetupStepKind kind) {
    if (!_setup.draftOf(kind).canContinue) {
      // The API has no "unanswered" value to go back to: ask for a choice instead.
      _queue.remove(kind);
      setState(() => _saveStatus = HealthSaveStatus.unsaved);
      return;
    }
    if (_saveStatus == HealthSaveStatus.unsaved ||
        _saveStatus == HealthSaveStatus.failed) {
      setState(() => _saveStatus = HealthSaveStatus.idle);
    }
    _queue.add(kind);
    _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      final kind = _queue.first;
      _queue.remove(kind);
      await _save(kind);
    }
  }

  Future<void> _save(HealthSetupStepKind kind) async {
    final result = await _setup.saveStep(kind);
    if (!mounted) return;
    if (result == HealthSetupSaveResult.saved) {
      if (kind == HealthSetupStepKind.condition) {
        // Disease links changed on the server: refresh the profile (disease count).
        unawaited(ProfileScope.read(context).load());
      }
      if (_saveStatus != HealthSaveStatus.idle) {
        setState(() => _saveStatus = HealthSaveStatus.idle);
      }
      return;
    }
    if (result != HealthSetupSaveResult.failed) return;
    _queue.clear();
    setState(() => _saveStatus = HealthSaveStatus.failed);
    _reactions.react(MascotMood.concerned);
    if (_setup.conflict) {
      // Changed elsewhere: show what is stored now rather than overwrite it.
      await _setup.load();
      if (mounted) {
        _snack('Hồ sơ vừa được cập nhật ở nơi khác. Đã tải lại để bạn xem.');
      }
      return;
    }
    // The hero chip may be scrolled away: say it where the user is.
    _snack('Chưa lưu được thay đổi.',
        action: SnackBarAction(label: 'Thử lại', onPressed: _retry));
  }

  void _retry() {
    for (final kind in HealthSetupStepKind.values) {
      if (_setup.snapshot != null && _setup.draftOf(kind).canContinue) {
        _autosave(kind);
      }
    }
  }

  void _snack(String text, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(text),
            action: action,
            duration: const Duration(seconds: 4)));

  // ---------------------------------------------------------------- allergies

  void _allergyChanged() {
    final draft = _setup.allergyDraft;
    if (draft.ids.isNotEmpty || draft.names.isNotEmpty) {
      _reactions.react(MascotMood.protect);
    }
    setState(() {});
    _autosave(HealthSetupStepKind.allergy);
  }

  Future<void> _addCustom({required bool allergy}) async {
    _reactions.react(MascotMood.thinking, hold: const Duration(seconds: 30));
    final value = await showHealthSetupCustomSheet(context, allergy: allergy);
    if (!mounted) return;
    _mascot.play(MascotMood.idle);
    if (value == null) return;
    final draft = allergy ? _setup.allergyDraft : _setup.conditionDraft;
    if (!draft.addCustom(value)) {
      _snack('Mục đã có hoặc tên không hợp lệ.');
      return;
    }
    _reactions.react(allergy ? MascotMood.protect : MascotMood.concerned);
    setState(() {});
    _autosave(
        allergy ? HealthSetupStepKind.allergy : HealthSetupStepKind.condition);
  }

  void _removeCustom({required bool allergy, required String name}) {
    final draft = allergy ? _setup.allergyDraft : _setup.conditionDraft;
    setState(() => draft.names.remove(name));
    _autosave(
        allergy ? HealthSetupStepKind.allergy : HealthSetupStepKind.condition);
  }

  // ---------------------------------------------------------------- diseases

  void _diseaseChanged() {
    if (_setup.conditionDraft.ids.isNotEmpty) {
      _reactions.react(MascotMood.concerned);
    }
    setState(() {});
    _autosave(HealthSetupStepKind.condition);
  }

  void _toggleNoDisease() {
    setState(() => _setup.conditionDraft.toggleNone());
    if (_setup.conditionDraft.noneKnown) _reactions.react(MascotMood.celebrate);
    _autosave(HealthSetupStepKind.condition);
  }

  // ---------------------------------------------------------------- physiological

  String _physiologicalSummary() {
    final draft = _setup.physiologicalDraft;
    if (draft.noneKnown) return 'Không';
    final names = {for (final o in _setup.physiologicalOptions) o.id: o.name};
    final picked = [for (final id in draft.ids) names[id] ?? 'Đã khai báo'];
    return picked.isEmpty ? 'Chưa khai báo' : picked.join(', ');
  }

  Future<void> _openPhysiological() async {
    await Navigator.of(context).pushNamed(AppRoutes.physiologicalState);
    if (!mounted) return;
    unawaited(_load());
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    return Scaffold(
      backgroundColor: HealthProfileStyle.canvas,
      appBar: ProfileFlowHeader('Hồ sơ sức khỏe',
          titleScale: MediaQuery.textScalerOf(context).scale(18) / 18,
          backgroundColor: HealthProfileStyle.canvas),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _setup,
          builder: (context, _) => RefreshIndicator(
            onRefresh: () async {
              await profile.load();
              await _load();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                HealthHeroCard(
                  mascot: _mascot,
                  title: 'Dumi giữ hồ sơ giúp bạn',
                  subtitle:
                      'Dị ứng và bệnh nền giúp cảnh báo thuốc, gợi ý món phù hợp.',
                  status: _saveStatus,
                  onRetry: _retry,
                ),
                const SizedBox(height: 16),
                const ProfileNotices(),
                ..._sections(profile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(ProfileController profile) {
    if (profile.denied) return const [];
    final waiting = (profile.loading && profile.profile == null) ||
        (_setup.loading && _setup.snapshot == null);
    if (waiting) return const [ProfileLoading()];
    if (_setup.loadFailed || widget.repository == null) {
      return [
        HealthStateMessage(
          text: 'Dumi chưa tải được hồ sơ sức khỏe.',
          action: widget.repository == null ? null : 'Thử lại',
          onAction: _load,
        ),
      ];
    }
    if (_setup.snapshot == null) return const [];
    final male = profile.profile?.isMale ?? false;
    return [
      _allergySection(),
      const SizedBox(height: 16),
      _diseaseSection(profile),
      if (!male) ...[
        const SizedBox(height: 16),
        _physiologicalTile(),
      ],
    ];
  }

  Widget _allergySection() {
    final draft = _setup.allergyDraft;
    return HealthSectionCard(
      key: const Key('health-allergy-section'),
      icon: Icons.warning_amber_rounded,
      title: 'Dị ứng thuốc & thực phẩm',
      subtitle: 'Chạm để chọn hoặc bỏ chọn.',
      tint: const Color(0xFFFDF0E1),
      iconColor: const Color(0xFFB45C0D),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HealthSetupOptionGrid<String>(
          allergy: true,
          options: _setup.allergenOptions,
          draft: draft,
          onChanged: _allergyChanged,
        ),
        if (draft.names.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final name in draft.names)
              HealthTag(
                key: Key('allergy-custom-$name'),
                label: name,
                removable: true,
                onTap: () => _removeCustom(allergy: true, name: name),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: HealthTag(
            key: const Key('allergy-add'),
            label: 'Thêm dị ứng khác',
            selected: false,
            onTap: () => _addCustom(allergy: true),
          ),
        ),
        const SizedBox(height: 8),
        HealthNoneToggle(
          key: const Key('allergy-none'),
          label: 'Tôi không có dị ứng đã biết',
          value: draft.noneKnown,
          onChanged: () {
            setState(draft.toggleNone);
            if (draft.noneKnown) _reactions.react(MascotMood.celebrate);
            _autosave(HealthSetupStepKind.allergy);
          },
        ),
      ]),
    );
  }

  Widget _diseaseSection(ProfileController profile) {
    final draft = _setup.conditionDraft;
    return HealthSectionCard(
      key: const Key('health-disease-section'),
      icon: Icons.favorite_border,
      title: 'Bệnh nền',
      subtitle: 'Chọn các bệnh đã được chẩn đoán.',
      tint: const Color(0xFFEFE8FA),
      iconColor: const Color(0xFF7450BC),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HealthSetupOptionGrid<int>(
          allergy: false,
          // Chronic diseases only: pregnancy and breastfeeding have their own screen.
          options: _setup.chronicOptions,
          draft: draft,
          onChanged: _diseaseChanged,
        ),
        if (draft.names.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final name in draft.names)
              HealthTag(
                key: Key('condition-custom-$name'),
                label: name,
                removable: true,
                onTap: () => _removeCustom(allergy: false, name: name),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: HealthTag(
            key: const Key('condition-add'),
            label: 'Thêm bệnh nền khác',
            selected: false,
            onTap: () => _addCustom(allergy: false),
          ),
        ),
        const SizedBox(height: 8),
        HealthNoneToggle(
          key: const Key('condition-none'),
          label: 'Tôi không có bệnh nền đã biết',
          value: draft.noneKnown,
          onChanged: _toggleNoDisease,
        ),
      ]),
    );
  }

  Widget _physiologicalTile() {
    final summary = _physiologicalSummary();
    return Semantics(
      button: true,
      label: 'Tình trạng sinh lý: $summary',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const Key('physiological-tile'),
          borderRadius: BorderRadius.circular(20),
          onTap: _openPhysiological,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.cardElevation),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: HealthProfileStyle.pink,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.pregnant_woman,
                    color: HealthProfileStyle.pinkInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tình trạng sinh lý',
                          style: AppTextStyles.bodyStrong),
                      Text(summary,
                          key: const Key('physiological-summary'),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.inkMuted)),
                    ]),
              ),
              Transform.rotate(
                angle: math.pi,
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 16, color: AppColors.inkMuted),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
