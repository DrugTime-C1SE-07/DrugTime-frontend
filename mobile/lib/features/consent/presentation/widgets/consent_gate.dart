import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/presentation/state/auth_controller.dart';
import '../../domain/entities/consent.dart';
import '../../domain/entities/consent_failure.dart';
import '../screens/consent_screen.dart';
import '../screens/terms_update_screen.dart';
import '../state/consent_controller.dart';

/// Đặt ở route Trang chủ: mọi đường vào app (mở app có phiên, OTP, hoàn tất hồ sơ) đều qua đây.
///
/// Hỏi server một lần mỗi khi được dựng, rồi xét theo thứ tự:
/// 1. Không tải được (mất mạng): vào [child]. Server vẫn chặn bằng `consent_revoked`, và câu lỗi
///    dẫn người dùng tới màn đồng ý.
/// 2. Chưa đồng ý điều khoản (hoặc đồng ý bản cũ) nhưng vừa tick ở màn đăng nhập: ghi `terms`
///    lên server, không hỏi lại. Ghi lỗi thì sang bước 3.
/// 3. Vẫn thiếu điều khoản: màn "Điều khoản đã cập nhật".
/// 4. Chưa có `health_data`: màn đồng ý.
/// 5. Còn lại: [child].
///
/// Quyết định chỉ chốt sau lần tải đó: rút consent sau này (màn Quyền riêng tư) không kéo người
/// dùng về màn onboarding.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key, required this.child});

  final Widget child;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

enum _GateState { checking, needsTerms, needsConsent, open }

class _ConsentGateState extends State<ConsentGate> {
  _GateState _state = _GateState.checking;

  @override
  void initState() {
    super.initState();
    // Sau frame đầu: load() báo thay đổi ngay, không được gọi trong lúc đang build.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  Future<void> _check() async {
    final consents = ConsentScope.read(context);
    // Không đăng ký rebuild (đang ở callback); không có AuthScope khi dựng lẻ trong test.
    final acceptedAtLogin =
        context.getInheritedWidgetOfExactType<AuthScope>()?.notifier?.termsAccepted ?? false;
    await consents.load();
    if (!mounted) return;
    if (consents.loadError != null) {
      setState(() => _state = _GateState.open);
      return;
    }
    if (consents.needsTerms && acceptedAtLogin) {
      try {
        await consents.grant(ConsentPurpose.terms);
      } on ConsentFailure {
        // Không ghi được (mạng, phiên): hỏi lại bằng màn điều khoản ở bước dưới.
      }
      if (!mounted) return;
    }
    setState(() => _state = consents.needsTerms ? _GateState.needsTerms : _afterTerms(consents));
  }

  _GateState _afterTerms(ConsentController consents) =>
      consents.hasHealthData ? _GateState.open : _GateState.needsConsent;

  @override
  Widget build(BuildContext context) => switch (_state) {
        _GateState.checking => const Scaffold(
            key: Key('consent-gate-checking'),
            body: Center(child: CircularProgressIndicator()),
          ),
        _GateState.needsTerms => TermsUpdateScreen(
            onAccepted: () => setState(() => _state = _afterTerms(ConsentScope.read(context))),
          ),
        _GateState.needsConsent => ConsentScreen(
            onCompleted: () => setState(() => _state = _GateState.open),
          ),
        _GateState.open => widget.child,
      };
}
