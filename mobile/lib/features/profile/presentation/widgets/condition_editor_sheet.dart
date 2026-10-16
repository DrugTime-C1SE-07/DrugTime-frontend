import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../data/models/profile_api_mapper.dart';
import '../../domain/entities/condition.dart';
import '../state/profile_controller.dart';
import 'profile_form_fields.dart';
import 'profile_notices.dart';

Future<void> showConditionEditor(
        BuildContext context, ProfileCondition condition) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ConditionEditorSheet(condition: condition));

class ConditionEditorSheet extends StatefulWidget {
  const ConditionEditorSheet({super.key, required this.condition});
  final ProfileCondition condition;
  @override
  State<ConditionEditorSheet> createState() => _ConditionEditorSheetState();
}

class _ConditionEditorSheetState extends State<ConditionEditorSheet> {
  late final _subtype =
      TextEditingController(text: widget.condition.subtype ?? '');
  late final _stage = TextEditingController(text: widget.condition.stage ?? '');
  int? _generation;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _generation ??= ProfileScope.read(context).generation;
  }

  @override
  void dispose() {
    _subtype.dispose();
    _stage.dispose();
    super.dispose();
  }

  String? _value(String v) => v.trim().isEmpty ? null : v.trim();
  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    final valid = _generation == c.generation && !c.denied;
    if (!valid) {
      _subtype.clear();
      _stage.clear();
    }
    return SingleChildScrollView(
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (valid)
                    Text(widget.condition.name, style: AppTextStyles.heading),
                  const ProfileNotices(),
                  if (valid) ...[
                    const SizedBox(height: 16),
                    ProfileField(
                        label: 'Phân loại',
                        child: TextField(
                            key: const Key('condition-subtype'),
                            controller: _subtype,
                            enabled: !c.saving)),
                    ProfileField(
                        label: 'Giai đoạn',
                        child: TextField(
                            key: const Key('condition-stage'),
                            controller: _stage,
                            enabled: !c.saving)),
                    FilledButton(
                        onPressed: c.saving
                            ? null
                            : () async {
                                final changes =
                                    ProfileApiMapper.metadataChanges(
                                        widget.condition,
                                        subtype: _value(_subtype.text),
                                        stage: _value(_stage.text));
                                final saved = await c.updateCondition(
                                    widget.condition.id, changes);
                                if (context.mounted && saved) {
                                  Navigator.pop(context);
                                }
                              },
                        child: Text(
                            c.saving ? 'Đang lưu…' : 'Lưu thông tin bệnh')),
                    TextButton(
                        onPressed: c.saving
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                            title: const Text(
                                                'Xóa bệnh khỏi hồ sơ?'),
                                            content: const Text(
                                                'Bệnh sẽ được bỏ khỏi hồ sơ của bạn.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Hủy')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('Xóa'))
                                            ]));
                                if (!context.mounted ||
                                    confirmed != true ||
                                    _generation != c.generation) {
                                  return;
                                }
                                final removed = await c
                                    .deleteCondition(widget.condition.id);
                                if (context.mounted && removed) {
                                  Navigator.pop(context);
                                }
                              },
                        child: const Text('Xóa bệnh khỏi hồ sơ')),
                  ],
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng')),
                ])));
  }
}
