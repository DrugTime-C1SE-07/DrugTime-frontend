import 'package:flutter/material.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/profile_failure.dart';
import '../state/profile_controller.dart';

class ProfileNotices extends StatelessWidget {
  const ProfileNotices({super.key, this.hideSuccessNotice = false});
  final bool hideSuccessNotice;
  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.error case final error?) ...[
        Semantics(
            liveRegion: true,
            child: Text(error.message,
                style: AppTextStyles.body.copyWith(color: AppColors.danger))),
        if (error.kind == ProfileFailureKind.consent)
          TextButton(
              onPressed: () async {
                await Navigator.pushNamed(context, AppRoutes.consent);
                if (context.mounted) await c.load();
              },
              child: const Text('Xem và đồng ý'))
        else if (error.kind != ProfileFailureKind.unauthorized &&
            error.kind != ProfileFailureKind.unsupported)
          TextButton(
              onPressed: c.loading || c.saving ? null : c.load,
              child: const Text('Tải lại hồ sơ')),
        const SizedBox(height: AppSpacing.md),
      ],
      if (c.notice case final message? when
          !hideSuccessNotice || c.error != null || message != 'Đã lưu thay đổi')
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(liveRegion: true, child: Text(message))),
    ]);
  }
}

class ProfileLoading extends StatelessWidget {
  const ProfileLoading({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Đang tải hồ sơ',
      child: Column(children: [
        for (var i = 0; i < 3; i++)
          Container(
              height: 56,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.field))),
      ]));
}
