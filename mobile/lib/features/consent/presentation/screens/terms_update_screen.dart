import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/consent.dart';
import '../../domain/entities/consent_failure.dart';
import '../state/consent_controller.dart';
import '../widgets/consent_texts.dart';
import '../widgets/terms_agreement_row.dart';

/// Hỏi đồng ý điều khoản khi người dùng có phiên nhưng chưa đồng ý (người dùng có từ trước khi
/// có ô tick) hoặc đã đồng ý bản cũ. Nằm trong cổng ở Trang chủ; không có nút quay lại.
class TermsUpdateScreen extends StatefulWidget {
  const TermsUpdateScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<TermsUpdateScreen> createState() => _TermsUpdateScreenState();
}

class _TermsUpdateScreenState extends State<TermsUpdateScreen> {
  bool _accepted = false;
  bool _showError = false;
  bool _saving = false;

  Future<void> _continue() async {
    if (_saving) return;
    if (!_accepted) {
      setState(() => _showError = true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ConsentScope.read(context).grant(ConsentPurpose.terms);
    } on ConsentFailure catch (failure) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(consentFailureMessage(failure))));
      return;
    }
    if (mounted) widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Điều khoản đã cập nhật'),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.canvas,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            const Text(
              'DrugTime đã cập nhật điều khoản sử dụng. Để tiếp tục, vui lòng đọc và đồng ý hai văn '
              'bản bên dưới. Bấm vào tên văn bản để đọc toàn bộ nội dung.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            TermsAgreementRow(
              value: _accepted,
              onChanged: _saving
                  ? null
                  : (v) => setState(() {
                        _accepted = v;
                        if (v) _showError = false;
                      }),
              errorText: _showError
                  ? 'Vui lòng đồng ý Điều khoản dịch vụ và Chính sách quyền riêng tư'
                  : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const Key('terms-update-continue'),
              onPressed: _saving ? null : _continue,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.primaryButton),
              ),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Đồng ý và tiếp tục'),
            ),
          ],
        ),
      ),
    );
  }
}
