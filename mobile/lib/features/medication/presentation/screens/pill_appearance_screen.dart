import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/pill_appearance.dart';
import '../widgets/medication_confirm_view.dart';
import '../widgets/pill_appearance_icon.dart';

/// Kết quả của S07-M2b.
typedef PillAppearanceChoice = (PillShape, PillColor);

/// Mở S07-M2b; trả lựa chọn khi bấm "Dùng hình này", `null` khi quay lại.
Future<PillAppearanceChoice?> showPillAppearanceScreen(
  BuildContext context, {
  required String drugName,
  String? dosageForm,
  PillShape? shape,
  PillColor? color,
}) =>
    Navigator.of(context).push<PillAppearanceChoice>(MaterialPageRoute(
      builder: (_) => PillAppearanceScreen(
        drugName: drugName,
        initialShape: shape ?? PillShape.suggestFor(dosageForm),
        initialColor: color ?? PillColor.white,
      ),
    ));

/// S07-M2b "Dạng & màu thuốc": người bệnh chọn hình và màu để nhận ra thuốc ở mọi nơi trong app.
/// Chỉ để hiển thị, không đổi dạng bào chế của danh mục.
class PillAppearanceScreen extends StatefulWidget {
  const PillAppearanceScreen({
    super.key,
    required this.drugName,
    required this.initialShape,
    required this.initialColor,
  });

  final String drugName;
  final PillShape initialShape;
  final PillColor initialColor;

  @override
  State<PillAppearanceScreen> createState() => _PillAppearanceScreenState();
}

class _PillAppearanceScreenState extends State<PillAppearanceScreen> {
  late PillShape _shape = widget.initialShape;
  late PillColor _color = widget.initialColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AddFlowColors.background,
      appBar: addFlowAppBar(context, 'Dạng & màu thuốc'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          const AddFlowProgress(step: 3, label: 'Bước 3/3 · Xác nhận'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  PillAppearanceTile(
                      key: const Key('pill-preview'),
                      shape: _shape,
                      color: _color,
                      size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.drugName, style: AppTextStyles.title),
                          const SizedBox(height: 2),
                          Text('Hiện ở mọi nơi trong app',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.inkMuted)),
                        ]),
                  ),
                ]),
                const SizedBox(height: 20),
                const Text('Dạng thuốc', style: AppTextStyles.bodyStrong),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.78,
                  children: [
                    for (final shape in PillShape.values)
                      _ShapeOption(
                        shape: shape,
                        color: _color,
                        selected: shape == _shape,
                        onTap: () => setState(() => _shape = shape),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Màu viên', style: AppTextStyles.bodyStrong),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.8,
                  children: [
                    for (final color in PillColor.values)
                      _ColorOption(
                        color: color,
                        selected: color == _color,
                        onTap: () => setState(() => _color = color),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AddFlowBottomBar(children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('use-pill-appearance'),
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton)),
            onPressed: () => Navigator.of(context).pop((_shape, _color)),
            icon: const Icon(LucideIcons.check),
            label: const Text('Dùng hình này'),
          ),
        ),
      ]),
    );
  }
}

class _ShapeOption extends StatelessWidget {
  const _ShapeOption({
    required this.shape,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final PillShape shape;
  final PillColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: shape.label,
        excludeSemantics: true,
        child: InkWell(
          key: Key('pill-shape-${shape.apiValue}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0DF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected ? AppColors.brand : AppColors.border,
                    width: selected ? 2.5 : 1),
              ),
              child: PillAppearanceIcon(shape: shape, color: color, size: 32),
            ),
            const SizedBox(height: 4),
            Text(
              shape.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.brand : AppColors.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ]),
        ),
      );
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final PillColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Màu ${color.label}',
        excludeSemantics: true,
        child: InkWell(
          key: Key('pill-color-${color.apiValue}'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? AppColors.brand : Colors.transparent,
                    width: 2.5),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              color.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.brand : AppColors.ink,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ]),
        ),
      );
}
