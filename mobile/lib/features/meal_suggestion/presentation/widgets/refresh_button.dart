import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/mascot/mascot_view.dart';
import 'meal_ui.dart';

/// Nút "Gợi ý khác" (AC9, AC9b).
///
/// Còn lượt → mở màn chờ một bữa; đang mở → bỏ qua mọi lần bấm thêm;
/// hết lượt → dạng khóa, bấm thì rung nhẹ + sheet giải thích (không im lặng).
class MealRefreshButton extends StatelessWidget {
  const MealRefreshButton({
    super.key,
    required this.busy,
    required this.left,
    required this.onTap,
    required this.onLocked,
  });

  final bool busy;
  final int left;
  final VoidCallback onTap, onLocked;

  @override
  Widget build(BuildContext context) {
    final locked = left <= 0;
    return Semantics(
      button: true,
      enabled: !busy,
      label:
          locked ? 'Hết lượt gợi ý khác hôm nay' : 'Gợi ý khác, còn $left lượt',
      excludeSemantics: true,
      child: Pressable(
        key: const ValueKey('refresh'),
        onTap: busy
            ? null
            : () {
                if (locked) {
                  HapticFeedback.lightImpact();
                  onLocked();
                } else {
                  onTap();
                }
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: locked ? const Color(0xFFEDEFEC) : MealColors.mint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: locked ? const Color(0xFFDDE1DE) : Colors.transparent),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: MealColors.brand),
                )
              else
                Icon(
                  locked ? Icons.lock_rounded : Icons.autorenew_rounded,
                  key: ValueKey(locked ? 'refresh-locked' : 'refresh-open'),
                  color: locked ? MealColors.ink2 : MealColors.brand,
                  size: locked ? 19 : 24,
                ),
              const SizedBox(width: 8),
              Text(
                locked ? 'Hết lượt gợi ý hôm nay' : 'Gợi ý khác',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: locked ? MealColors.ink2 : MealColors.brand),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Sheet giải thích khi hết lượt "Gợi ý khác" (bấm nút đã khóa, hoặc server trả 429).
/// Lượt đặt lại lúc 00:00 giờ VN, khớp backend.
Future<void> showRefreshLimitSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const MealTypography(child: _RefreshLimitSheet()),
    );

class _RefreshLimitSheet extends StatefulWidget {
  const _RefreshLimitSheet();
  @override
  State<_RefreshLimitSheet> createState() => _RefreshLimitSheetState();
}

class _RefreshLimitSheetState extends State<_RefreshLimitSheet> {
  final mascot = MascotController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => mascot.play(MascotMood.sleepy));
  }

  @override
  void dispose() {
    mascot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('refresh-limit-sheet'),
        padding: EdgeInsets.fromLTRB(
            22, 10, 22, 20 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                  color: MealColors.line,
                  borderRadius: BorderRadius.circular(4)),
            ),
            SizedBox(
              width: 130,
              height: 130,
              child: MascotView(
                  controller: mascot, outfit: MascotOutfit.chef, size: 130),
            ),
            const Text(
              'Hôm nay hết lượt gợi ý khác rồi',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: MealColors.ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mỗi ngày bạn có 2 lượt gợi ý khác. Lượt mới có từ 0 giờ ngày mai.\n'
              'Bạn vẫn vuốt thẻ để xem các món khác trong danh sách, hoặc chọn món đang có.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 15, color: MealColors.ink2, height: 1.45),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('refresh-limit-ok'),
                style: FilledButton.styleFrom(
                  backgroundColor: MealColors.brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      );
}
