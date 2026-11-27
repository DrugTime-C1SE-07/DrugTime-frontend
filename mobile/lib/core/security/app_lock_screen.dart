import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Màn "DrugTime đang khóa": tự hiện hộp thoại xác thực một lần khi xuất hiện.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.onUnlock,
    required this.onSignOut,
    this.canAutoPrompt,
  });

  final Future<bool> Function() onUnlock;
  final Future<void> Function() onSignOut;
  final bool Function()? canAutoPrompt;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.canAutoPrompt?.call() ?? true) unawaited(_unlock());
    });
  }

  Future<void> _unlock() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    final ok = await widget.onUnlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Chưa xác thực được. Bấm "Mở khóa" để thử lại.';
    });
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa hoàn tất đăng xuất. Vui lòng thử lại');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
        key: const Key('app-lock-screen'),
        color: AppColors.brandStrong,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(children: [
              const Spacer(),
              Semantics(
                header: true,
                label: 'DrugTime đang khóa',
                child: const Icon(Icons.lock_outline,
                    size: 64, color: AppColors.onBrand),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('DrugTime đang khóa',
                  style: AppTextStyles.title.copyWith(color: AppColors.onBrand),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Dùng Face ID, vân tay hoặc mã khóa màn hình để mở.',
                style: AppTextStyles.body.copyWith(color: AppColors.onBrand),
                textAlign: TextAlign.center,
              ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(error,
                    key: const Key('app-lock-error'),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.onBrand),
                    textAlign: TextAlign.center),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: AppSizes.primaryButton,
                child: FilledButton.icon(
                  key: const Key('app-lock-unlock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.brand,
                  ),
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Mở khóa'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                key: const Key('app-lock-sign-out'),
                style: TextButton.styleFrom(foregroundColor: AppColors.onBrand),
                onPressed: _busy ? null : _signOut,
                child: const Text('Đăng xuất'),
              ),
            ]),
          ),
        ),
      );
}
