import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/app_assets.dart';
import '../../../../shared/widgets/selectable_pill.dart';
import '../state/auth_controller.dart';

/// Hoàn thiện hồ sơ cơ bản sau lần đăng nhập OTP đầu tiên (`profile_complete = false`).
/// Gọi `POST /auth/profile`; thành công thì vào Trang chủ.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 60),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _submit(AuthController controller) async {
    final ok = await controller.completeProfile(
      fullName: _nameController.text,
      dateOfBirth: _dateOfBirth,
      gender: _gender,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } else if (!controller.isAuthenticated) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final controller = AuthScope.of(context);
    final error = controller.errorMessage;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Hoàn thiện hồ sơ'),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.canvas,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Center(
              child: Image.asset(
                AppAssets.mascotThinking,
                height: 120.0,
                cacheHeight: 360,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Cho DrugTime biết một chút về bạn để nhắc thuốc chính xác hơn.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Họ và tên', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('profile-full-name'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Ví dụ: Nguyễn Thị Lan'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Ngày sinh', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('profile-date-of-birth'),
              onPressed: controller.isLoading ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                _dateOfBirth == null ? 'Chọn ngày sinh' : _formatDate(_dateOfBirth!),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.field),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('Giới tính', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final entry in AuthController.genders.entries)
                  SelectablePill(
                    label: entry.value,
                    selected: _gender == entry.key,
                    onTap: () => setState(() => _gender = entry.key),
                  ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                error,
                key: const Key('profile-error'),
                style: AppTextStyles.body.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const Key('profile-submit'),
              onPressed: controller.isLoading ? null : () => _submit(controller),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              child: controller.isLoading
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Lưu và tiếp tục'),
            ),
          ],
        ),
      ),
    );
  }
}
