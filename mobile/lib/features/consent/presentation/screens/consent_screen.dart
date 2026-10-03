import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../medication/presentation/state/medication_controller.dart';
import '../../domain/entities/consent.dart';
import '../../domain/entities/consent_failure.dart';
import '../state/consent_controller.dart';
import '../widgets/consent_purpose_card.dart';
import '../widgets/consent_texts.dart';

/// Màn đồng ý xử lý dữ liệu theo từng mục đích.
///
/// - Trong cổng ở Trang chủ (`onCompleted` khác null): bước onboarding, không có nút quay lại.
/// - Mở qua route (từ câu lỗi `consent_revoked`): xong thì `pop(true)`.
///
/// Mỗi mục đích một công tắc; không có nút đồng ý tất cả. `health_data` bắt buộc để tiếp tục.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  /// Lựa chọn trên màn; ban đầu theo trạng thái server (người mới: tất cả tắt).
  late final Map<ConsentPurpose, bool> _choices = {
    for (final p in ConsentPurpose.values) p: ConsentScope.read(context).isGranted(p),
  };
  bool _saving = false;

  bool get _canContinue => _choices[ConsentPurpose.healthData]! && !_saving;

  Future<void> _continue() async {
    if (!_canContinue) return;
    final consents = ConsentScope.read(context);
    final medications = MedicationScope.read(context);
    setState(() => _saving = true);
    try {
      // Tuần tự, từng mục một; mục đã khớp server (kể cả do lần bấm trước) thì không gửi lại.
      for (final purpose in ConsentPurpose.values) {
        final wanted = _choices[purpose]!;
        if (wanted == consents.isGranted(purpose)) continue;
        if (wanted) {
          await consents.grant(purpose);
        } else {
          await consents.withdraw(purpose);
        }
      }
    } on ConsentFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(consentFailureMessage(failure))));
      return;
    }
    // Lần tải danh sách thuốc trước khi có consent đã nhận 403; tải lại.
    await medications.load();
    if (!mounted) return;
    final onCompleted = widget.onCompleted;
    if (onCompleted != null) {
      onCompleted();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final standalone = widget.onCompleted == null;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Quyền riêng tư của bạn'),
        automaticallyImplyLeading: standalone,
        backgroundColor: AppColors.canvas,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text(
              'DrugTime chỉ xử lý dữ liệu của bạn cho những mục đích bạn đồng ý. '
              'Mỗi mục đích được chọn riêng và có thể thay đổi bất cứ lúc nào.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final purpose in ConsentPurpose.values) ...[
              ConsentPurposeCard(
                purpose: purpose,
                value: _choices[purpose]!,
                onChanged: _saving ? null : (v) => setState(() => _choices[purpose] = v),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (!_choices[ConsentPurpose.healthData]!) ...[
              Text(
                'Bật "${consentTexts[ConsentPurpose.healthData]!.title}" để tiếp tục.',
                key: const Key('consent-required-hint'),
                style: AppTextStyles.caption.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('consent-continue'),
              onPressed: _canContinue ? _continue : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Tiếp tục'),
            ),
          ],
        ),
      ),
    );
  }
}
