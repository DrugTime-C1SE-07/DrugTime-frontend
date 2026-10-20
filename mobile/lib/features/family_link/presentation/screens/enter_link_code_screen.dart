import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/link_code.dart';
import '../state/family_link_scope.dart';
import '../state/link_request_controller.dart';
import '../widgets/link_code_input_formatter.dart';
import '../widgets/link_request_messages.dart';

/// Tham số mở màn nhập mã: từ màn quét (tự gửi) hoặc từ link mời (không tự gửi).
class EnterLinkCodeArgs {
  const EnterLinkCodeArgs({
    this.initialCode,
    this.autoSubmit = false,
    this.invalidLink = false,
  });

  final String? initialCode;

  /// Chỉ dùng khi mã đến từ màn quét: người dùng đã chủ động quét. Link mời không bao giờ tự gửi.
  final bool autoSubmit;

  /// Mở từ link mời không đọc được mã.
  final bool invalidLink;
}

/// Người thân nhập mã liên kết của patient và gửi yêu cầu (QD-04: patient phải chấp thuận).
class EnterLinkCodeScreen extends StatefulWidget {
  const EnterLinkCodeScreen({super.key, this.args = const EnterLinkCodeArgs()});

  final EnterLinkCodeArgs args;

  @override
  State<EnterLinkCodeScreen> createState() => _EnterLinkCodeScreenState();
}

class _EnterLinkCodeScreenState extends State<EnterLinkCodeScreen> {
  late final FamilyLinkScope _scope = FamilyLinkScope.read(context);
  late final LinkRequestController _controller =
      LinkRequestController(_scope.repository, inviteLinkHost: _scope.inviteLinkHost);
  final _field = TextEditingController();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.args.initialCode;
    if (initial != null && isValidLinkCode(initial)) {
      _field.text = groupLinkCode(initial);
      _controller.updateInput(initial);
    }
    _controller.addListener(_onControllerChanged);
    if (widget.args.autoSubmit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_controller.submit());
      });
    }
  }

  void _onControllerChanged() {
    final outcome = _controller.outcome;
    if (outcome != null && !_navigated && mounted) {
      _navigated = true;
      unawaited(Navigator.of(context)
          .pushReplacementNamed(AppRoutes.familyLinkResult, arguments: outcome));
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập mã liên kết')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              const Text(
                'Nhập mã 10 ký tự mà người thân chia sẻ với bạn. Người thân xem mã trong app '
                'DrugTime, mục Người thân → Mã liên kết của tôi.',
                style: AppTextStyles.body,
              ),
              if (widget.args.invalidLink) ...[
                const SizedBox(height: AppSpacing.lg),
                const _Notice(
                  key: Key('invalid-invite-link'),
                  message: invalidInviteLinkMessage,
                  color: AppColors.caution,
                  background: AppColors.cautionBg,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              TextField(
                key: const Key('link-code-field'),
                controller: _field,
                enabled: !_controller.isSending,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                keyboardType: TextInputType.visiblePassword,
                style: AppTextStyles.title.copyWith(letterSpacing: 2),
                inputFormatters: [
                  LinkCodeInputFormatter(inviteLinkHost: _scope.inviteLinkHost),
                ],
                decoration: InputDecoration(
                  labelText: 'Mã liên kết',
                  hintText: 'XXXX XXXX XX',
                  errorText: linkCodeFormatError(
                    _controller.normalizedInput,
                    valid: _controller.code != null,
                  ),
                ),
                onChanged: _controller.updateInput,
                onSubmitted: (_) => unawaited(_controller.submit()),
              ),
              if (_controller.error case final error?) ...[
                const SizedBox(height: AppSpacing.lg),
                _Notice(
                  key: const Key('link-request-error'),
                  message: linkSubmitErrorMessage(error, remaining: _controller.remaining),
                  color: AppColors.danger,
                  background: AppColors.dangerBg,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: AppSizes.primaryButton,
                child: FilledButton(
                  key: const Key('link-code-submit'),
                  onPressed: _controller.canSubmit ? () => unawaited(_controller.submit()) : null,
                  child: _controller.isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            key: Key('link-code-sending'),
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(_controller.error?.isRetryable == true ? 'Thử lại' : 'Gửi yêu cầu'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Người thân cần chấp thuận yêu cầu thì bạn mới xem được thông tin của họ.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.message,
    required this.color,
    required this.background,
  });

  final String message;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTextStyles.body.copyWith(color: color))),
        ],
      ),
    );
  }
}
