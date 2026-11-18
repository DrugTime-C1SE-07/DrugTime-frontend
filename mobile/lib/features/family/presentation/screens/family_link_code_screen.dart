import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/router.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

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
      appBar: ProfileFlowHeader('Mã QR của bạn',
          titleScale: MediaQuery.textScalerOf(context).scale(18) / 18,
          backgroundColor: AppColors.canvas),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
              'Nhờ người thân mở DrugTime và chọn Quét mã QR để gửi yêu cầu kết nối.',
              style: AppTextStyles.caption),
          const SizedBox(height: 16),
          ProfileFlowCard(
              child: Column(children: [
            QrImageView(
                key: const Key('family-link-qr'),
                data: qrPayload,
                size: 220,
                semanticsLabel: 'Mã QR liên kết người thân'),
            const SizedBox(height: 20),
            const Text('Mã liên kết', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            SelectableText(code,
                key: const Key('family-link-code'),
                style: AppTextStyles.bodyStrong
                    .copyWith(fontSize: 18, letterSpacing: 2),
                textAlign: TextAlign.center),
          ])),
          const SizedBox(height: 16),
          ProfileFlowButton(
              label: 'Chia sẻ link mời',
              icon: Icons.share_outlined,
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.familyShareLink)),
          const SizedBox(height: 16),
          const Text(
              'Người thân gửi yêu cầu bằng mã này. Liên kết chỉ được tạo sau khi bạn chấp thuận.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center),
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
