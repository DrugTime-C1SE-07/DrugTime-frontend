import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/meal_suggestion.dart';
import '../state/dietary_session.dart';

/// Kết quả sheet khai hạn chế ăn uống và sở thích (QD-40). `null` khi người dùng đóng sheet.
class DietaryAnswer {
  const DietaryAnswer({required this.restrictions, required this.preferences});

  /// `null`: người dùng chọn "Chưa biết" → không gọi API gợi ý.
  final DietaryDeclaration? restrictions;
  final List<String> preferences;
}

Future<DietaryAnswer?> showDietarySheet(BuildContext context,
    {DietarySession? session}) {
  return showModalBottomSheet<DietaryAnswer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DietarySheet(session: session ?? DietarySession.instance),
  );
}

enum _RestrictionMode { none, list, unknown }

class DietarySheet extends StatefulWidget {
  const DietarySheet(
      {super.key, required this.session, this.onSubmit, this.showTitle = true});

  final DietarySession session;

  /// Khác `null`: sheet được nhúng (sheet "Dumi cần biết"), gọi callback thay vì đóng route.
  final ValueChanged<DietaryAnswer>? onSubmit;
  final bool showTitle;

  @override
  State<DietarySheet> createState() => _DietarySheetState();
}

class _DietarySheetState extends State<DietarySheet> {
  _RestrictionMode? _mode;
  final _restrictionInput = TextEditingController();
  final _preferenceInput = TextEditingController();
  late List<String> _restrictions;
  late List<String> _preferences;

  @override
  void initState() {
    super.initState();
    final current = widget.session.restrictions;
    _mode = current == null
        ? null
        : current.none
            ? _RestrictionMode.none
            : _RestrictionMode.list;
    _restrictions = [...?current?.items];
    _preferences = [...widget.session.preferences];
  }

  @override
  void dispose() {
    _restrictionInput.dispose();
    _preferenceInput.dispose();
    super.dispose();
  }

  String? get _restrictionError => _mode == _RestrictionMode.list
      ? (_restrictions.isEmpty
          ? 'Thêm ít nhất 1 hạn chế, hoặc chọn "Không có".'
          : validateDietaryItems(_restrictions, max: 10))
      : null;

  String? get _preferenceError => validateDietaryItems(_preferences, max: 5);

  bool get _valid =>
      _mode != null && _restrictionError == null && _preferenceError == null;

  void _add(TextEditingController input, List<String> target) {
    final value = input.text.trim();
    if (value.isEmpty) return;
    setState(() {
      target.add(value);
      input.clear();
    });
  }

  void _submit() {
    final restrictions = switch (_mode) {
      _RestrictionMode.none => const DietaryDeclaration.none(),
      _RestrictionMode.list =>
        DietaryDeclaration.items(_restrictions.map((e) => e.trim()).toList()),
      _ => null,
    };
    final answer = DietaryAnswer(
        restrictions: restrictions,
        preferences: _preferences.map((e) => e.trim()).toList());
    final onSubmit = widget.onSubmit;
    if (onSubmit != null) {
      onSubmit(answer);
    } else {
      Navigator.of(context).pop(answer);
    }
  }

  Widget _items(List<String> items) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final item in items)
            InputChip(
              label: Text(item),
              onDeleted: () => setState(() => items.remove(item)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              const Text('Trước khi gợi ý', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.xs),
            ],
            const Text(
                'Bạn có hạn chế ăn uống nào không? (ví dụ ăn chay, kiêng đường)',
                style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, children: [
              ChoiceChip(
                label: const Text('Không có'),
                selected: _mode == _RestrictionMode.none,
                onSelected: (_) =>
                    setState(() => _mode = _RestrictionMode.none),
              ),
              ChoiceChip(
                label: const Text('Có'),
                selected: _mode == _RestrictionMode.list,
                onSelected: (_) =>
                    setState(() => _mode = _RestrictionMode.list),
              ),
              ChoiceChip(
                label: const Text('Chưa biết'),
                selected: _mode == _RestrictionMode.unknown,
                onSelected: (_) =>
                    setState(() => _mode = _RestrictionMode.unknown),
              ),
            ]),
            if (_mode == _RestrictionMode.unknown)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                    'Dumi cần biết hạn chế ăn uống để gợi ý an tâm hơn. '
                    'Bạn khai khi đã rõ nhé.',
                    style: AppTextStyles.caption),
              ),
            if (_mode == _RestrictionMode.list) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('restriction-input'),
                controller: _restrictionInput,
                maxLength: 40,
                decoration: const InputDecoration(
                    hintText: 'Nhập hạn chế rồi bấm +', counterText: ''),
                onSubmitted: (_) => _add(_restrictionInput, _restrictions),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('restriction-add'),
                  onPressed: () => _add(_restrictionInput, _restrictions),
                  child: const Text('+ Thêm'),
                ),
              ),
              _items(_restrictions),
              if (_restrictionError case final e?)
                Text(e,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.lg),
            const Text('Sở thích (không bắt buộc, tối đa 5)',
                style: AppTextStyles.body),
            TextField(
              key: const ValueKey('preference-input'),
              controller: _preferenceInput,
              maxLength: 40,
              decoration: const InputDecoration(
                  hintText: 'Ví dụ: Ít cay, Món nước', counterText: ''),
              onSubmitted: (_) => _add(_preferenceInput, _preferences),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _add(_preferenceInput, _preferences),
                child: const Text('+ Thêm'),
              ),
            ),
            _items(_preferences),
            if (_preferenceError case final e?)
              Text(e,
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.danger)),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('dietary-submit'),
                onPressed: _valid ? _submit : null,
                child: const Text('Xem gợi ý'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
