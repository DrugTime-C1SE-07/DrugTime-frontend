import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Dòng đếm ngược và gửi lại mã OTP theo Figma:
/// - Kích thước: 327px x 19px, gap: 6px, căn giữa
/// - Khi đang đếm ngược: Icon Clock (14x14) + "Gửi lại mã sau mm:ss" (màu #5B6169)
/// - Khi hết giờ: Cho phép người dùng chạm vào "Gửi lại mã" (màu #01554F)
class OtpResendRow extends StatefulWidget {
  const OtpResendRow({
    super.key,
    this.initialCountdown = 60,
    required this.onResend,
    this.isResending = false,
  });

  final int initialCountdown;
  final Future<void> Function() onResend;
  final bool isResending;

  @override
  State<OtpResendRow> createState() => _OtpResendRowState();
}

class _OtpResendRowState extends State<OtpResendRow> {
  late int _remainingSeconds = widget.initialCountdown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = widget.initialCountdown;
    if (_remainingSeconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        setState(() => _remainingSeconds = 0);
        timer.cancel();
      }
    });
  }

  Future<void> _handleResend() async {
    if (widget.isResending || _remainingSeconds > 0) return;
    await widget.onResend();
    if (mounted) {
      _startTimer();
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds > 0) {
      return Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(LucideIcons.clock,
                size: 16.0, color: AppColors.inkMuted),
            const SizedBox(width: 6.0),
            Text(
              'Gửi lại mã sau',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                height: 18.0 / 12.5,
                color: AppColors.inkMuted,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatDuration(_remainingSeconds),
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                  fontFamily: 'Inter'),
            ),
          ],
        ),
      );
    }

    return TextButton(
      onPressed: widget.isResending ? null : _handleResend,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      child: const Text('Gửi lại mã'),
    );
  }
}
