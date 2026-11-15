import 'package:flutter/material.dart';

import '../../domain/entities/health_setup.dart';
import '../state/health_setup_controller.dart';

const healthSetupBrand = Color(0xff005653);
const healthSetupInk = Color(0xff211d1d);
const healthSetupMuted = Color(0xff59626b);
const healthSetupPaper = Color(0xfffafafa);
const healthSetupBorder = Color(0xffe0e3e4);
const _selectedFill = Color(0xffe6f3f1);

class HealthSetupPresentation {
  const HealthSetupPresentation(this.label, this.iconIndex);
  final String label;
  final int iconIndex;
}

const _allergyIcons = {
  'penicillin': 0,
  'aspirin': 1,
  'sulfa': 2,
  'cephalosporin': 3,
  'seafood': 4,
  'peanuts': 5,
  'eggs': 6,
  'milk': 7,
};

const _conditionPresentation = {
  'tăng huyết áp': HealthSetupPresentation('Tăng huyết áp', 8),
  'hypertension': HealthSetupPresentation('Tăng huyết áp', 8),
  'tiểu đường': HealthSetupPresentation('Tiểu đường', 9),
  'đái tháo đường': HealthSetupPresentation('Tiểu đường', 9),
  'diabetes mellitus': HealthSetupPresentation('Tiểu đường', 9),
  'tim mạch': HealthSetupPresentation('Tim mạch', 10),
  'thận': HealthSetupPresentation('Thận', 11),
  'gan': HealthSetupPresentation('Gan', 12),
  'hen / copd': HealthSetupPresentation('Hen / COPD', 13),
  'máu khó đông': HealthSetupPresentation('Máu khó đông', 14),
  'tuyến giáp': HealthSetupPresentation('Tuyến giáp', 15),
};

HealthSetupPresentation? _presentation<T>(HealthSetupOption<T> item) {
  if (item.category == null) {
    return _conditionPresentation[item.name.trim().toLowerCase()];
  }
  final icon = _allergyIcons[item.id];
  return icon == null ? null : HealthSetupPresentation(item.name, icon);
}

String healthSetupLabel<T>(HealthSetupOption<T> item) =>
    _presentation(item)?.label ?? item.name;

String healthSetupSummary<T>(HealthSetupStep<T> step,
    List<HealthSetupOption<T>> options, String noneMessage) {
  if (step.status == HealthSetupStatus.noneKnown) return noneMessage;
  if (step.status == HealthSetupStatus.unreported) return 'Chưa khai báo';
  final labels = {for (final item in options) item.id: healthSetupLabel(item)};
  final names = [
    for (final id in step.ids)
      if (labels[id] != null) labels[id]!,
    ...step.names,
  ];
  return names.isEmpty ? 'Xem trong hồ sơ' : names.join(', ');
}

class HealthSetupActionBar extends StatelessWidget {
  const HealthSetupActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.saving = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool saving;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffeeeeee))),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                backgroundColor: healthSetupBrand,
                disabledBackgroundColor: const Color(0xffe9ebea),
                disabledForegroundColor: healthSetupMuted,
                textStyle: const TextStyle(
                  fontFamily: 'WelcomeInter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                elevation: onPressed == null ? 0 : 2,
              ),
              child: saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(label),
            ),
          ),
        ),
      );
}

class HealthSetupHeader extends StatelessWidget {
  const HealthSetupHeader({super.key, required this.back, required this.skip});
  final VoidCallback? back;
  final VoidCallback? skip;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
        child: Row(
          children: [
            IconButton.filled(
              tooltip: 'Quay lại',
              onPressed: back,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(48),
                backgroundColor: _selectedFill,
                foregroundColor: healthSetupBrand,
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            const Expanded(
              child: Text('Hồ sơ sức khoẻ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      color: healthSetupInk,
                      fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: skip,
              style: TextButton.styleFrom(foregroundColor: healthSetupBrand),
              child: const Text('Bỏ qua',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class HealthSetupForm<T> extends StatelessWidget {
  const HealthSetupForm({
    super.key,
    required this.allergy,
    required this.options,
    required this.draft,
    required this.onChanged,
    required this.onAdd,
    this.warning,
  });

  final bool allergy;
  final List<HealthSetupOption<T>> options;
  final HealthSetupDraft<T> draft;
  final VoidCallback onChanged;
  final VoidCallback onAdd;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final ordered = [...options]..sort((left, right) {
        final a = _presentation(left)?.iconIndex ?? 99;
        final b = _presentation(right)?.iconIndex ?? 99;
        return a == b
            ? options.indexOf(left).compareTo(options.indexOf(right))
            : a.compareTo(b);
      });
    final unknown =
        draft.ids.where((id) => !options.any((item) => item.id == id));
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      children: [
        Text(allergy ? 'Bước 1/2 · Dị ứng' : 'Bước 2/2 · Bệnh nền',
            style: const TextStyle(
                color: healthSetupMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 7),
        Row(children: [
          const Expanded(child: _ProgressBar(healthSetupBrand)),
          const SizedBox(width: 8),
          Expanded(
              child: _ProgressBar(
                  allergy ? const Color(0xffccd1d3) : healthSetupBrand)),
        ]),
        const SizedBox(height: 10),
        Text(allergy ? 'Bạn dị ứng với gì?' : 'Bạn có bệnh nền nào?',
            style: const TextStyle(
                fontSize: 22,
                height: 1.25,
                color: healthSetupInk,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
            allergy
                ? 'Chọn tất cả mục phù hợp.'
                : 'Chọn các bệnh đã được chẩn đoán.',
            style: const TextStyle(
                fontSize: 16, color: healthSetupMuted, height: 1.45)),
        if (warning != null) ...[
          const SizedBox(height: 12),
          Semantics(
              liveRegion: true,
              child: Text(warning!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
        SizedBox(height: allergy ? 10 : 14),
        if (allergy) ...[
          _group('Thuốc', ordered.where((item) => item.category == 'drug')),
          const SizedBox(height: 14),
          _group('Thực phẩm', ordered.where((item) => item.category == 'food')),
        ] else if (ordered.isEmpty)
          const Text(
            'Danh mục bệnh nền chưa có mục nào. Bạn có thể tự nhập bên dưới.',
            style: TextStyle(color: healthSetupMuted),
          )
        else
          _grid(ordered),
        for (final id in unknown)
          _line('Mục đã lưu ($id)', Icons.check_circle, true, () {
            draft.toggle(id);
            onChanged();
          }),
        for (final name in draft.names.toList())
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _line(name, Icons.close, false, () {
              draft.names.remove(name);
              onChanged();
            }),
          ),
        const SizedBox(height: 12),
        _line(allergy ? 'Thêm dị ứng khác' : 'Thêm bệnh nền khác', Icons.add,
            false, onAdd),
        const SizedBox(height: 8),
        _line(
          allergy
              ? 'Tôi không có dị ứng đã biết'
              : 'Tôi không có bệnh nền đã biết',
          draft.noneKnown ? Icons.check_circle : Icons.circle_outlined,
          draft.noneKnown,
          () {
            draft.toggleNone();
            onChanged();
          },
          selection: true,
        ),
      ],
    );
  }

  Widget _group(String label, Iterable<HealthSetupOption<T>> items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: healthSetupInk)),
          const SizedBox(height: 4),
          _grid(items.toList()),
        ],
      );

  Widget _grid(List<HealthSetupOption<T>> items) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 265 ||
                  MediaQuery.textScalerOf(context).scale(16) > 24
              ? 1
              : 2;
          const gap = 12.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: allergy ? 9 : 12,
            children: [
              for (final item in items)
                SizedBox(width: width, child: _card(item)),
            ],
          );
        },
      );

  Widget _card(HealthSetupOption<T> option) {
    final selected = draft.ids.contains(option.id);
    final iconIndex = _presentation(option)?.iconIndex;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? _selectedFill : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: selected ? healthSetupBrand : healthSetupBorder,
              width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            draft.toggle(option.id);
            onChanged();
          },
          child: Container(
            constraints: BoxConstraints(minHeight: allergy ? 68 : 78),
            padding:
                EdgeInsets.fromLTRB(11, allergy ? 6 : 10, 10, allergy ? 6 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (iconIndex == null)
                      const SizedBox.square(
                          dimension: 32,
                          child: Icon(Icons.medical_services_outlined,
                              color: healthSetupBrand))
                    else
                      Image.asset('assets/icons/health_setup/$iconIndex.png',
                          width: 32, height: 32, excludeFromSemantics: true),
                    _indicator(selected),
                  ],
                ),
                SizedBox(height: allergy ? 0 : 4),
                Text(healthSetupLabel(option),
                    style: const TextStyle(
                        color: healthSetupInk,
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, IconData icon, bool selected, VoidCallback tap,
          {bool selection = false}) =>
      Semantics(
        button: true,
        selected: selection ? selected : null,
        child: Material(
          color: selected ? _selectedFill : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: selected ? healthSetupBrand : healthSetupBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(children: [
                if (selection)
                  _indicator(selected)
                else
                  Icon(icon, color: healthSetupBrand, size: 24),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            color: healthSetupInk,
                            fontSize: 16,
                            fontWeight: FontWeight.w600))),
              ]),
            ),
          ),
        ),
      );

  Widget _indicator(bool selected) => Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        size: 24,
        color: selected ? healthSetupBrand : const Color(0xffbfc8d0),
      );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      height: 6,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)));
}
