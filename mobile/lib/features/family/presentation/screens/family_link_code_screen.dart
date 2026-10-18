import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_theme.dart';
import '../state/family_link_code_controller.dart';
import '../../domain/entities/family_link_code_failure.dart';

class FamilyLinkCodeScreen extends StatefulWidget {
  const FamilyLinkCodeScreen({super.key});

  @override
  State<FamilyLinkCodeScreen> createState() => _FamilyLinkCodeScreenState();
}

class _FamilyLinkCodeScreenState extends State<FamilyLinkCodeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(FamilyLinkCodeScope.read(context).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = FamilyLinkCodeScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mời người thân')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: switch ((
              controller.isLoading,
              controller.code,
              controller.failure
            )) {
              (true, _, _) => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: CircularProgressIndicator(),
                ),
              (_, final code?, _) =>
                _buildCode(context, code.code, code.qrPayload),
              (_, _, final failure?) => _buildError(context, failure.kind),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCode(BuildContext context, String code, String qrPayload) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Chia sẻ mã này với người thân',
              style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: QrImageView(
              key: const Key('family-link-qr'),
              data: qrPayload,
              size: 220,
              semanticsLabel: 'Mã QR liên kết người thân',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text('Mã liên kết', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            code,
            key: const Key('family-link-code'),
            style: AppTextStyles.title.copyWith(letterSpacing: 3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Người thân gửi yêu cầu bằng mã này. Liên kết chỉ được tạo sau khi bạn chấp thuận.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildError(BuildContext context, FamilyLinkCodeFailureKind kind) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 48, color: AppColors.inkMuted),
          const SizedBox(height: AppSpacing.md),
          const Text('Chưa thể tải mã liên kết. Vui lòng thử lại.',
              style: AppTextStyles.body, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () =>
                unawaited(FamilyLinkCodeScope.read(context).load()),
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      );
}
