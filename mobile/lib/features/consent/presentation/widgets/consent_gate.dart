import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/consent_screen.dart';
import '../state/consent_controller.dart';

/// Đặt ở route Trang chủ: mọi đường vào app (mở app có phiên, OTP, hoàn tất hồ sơ) đều qua đây.
///
/// Hỏi server một lần mỗi khi được dựng. Chưa có `health_data` thì hiện màn đồng ý thay cho
/// [child]. Không tải được (mất mạng) thì vẫn vào [child]: server vẫn chặn bằng
/// `consent_revoked`, và câu lỗi dẫn người dùng tới màn đồng ý.
///
/// Quyết định chỉ chốt sau lần tải đó: rút consent sau này (màn Quyền riêng tư) không kéo người
/// dùng về màn onboarding.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key, required this.child});

  final Widget child;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

enum _GateState { checking, needsConsent, open }

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
    await consents.load();
    if (!mounted) return;
    setState(() {
      _state = consents.loadError == null && !consents.hasHealthData
          ? _GateState.needsConsent
          : _GateState.open;
    });
  }

  @override
  Widget build(BuildContext context) => switch (_state) {
        _GateState.checking => const Scaffold(
            key: Key('consent-gate-checking'),
            body: Center(child: CircularProgressIndicator()),
          ),
        _GateState.needsConsent => ConsentScreen(
            onCompleted: () => setState(() => _state = _GateState.open),
          ),
        _GateState.open => widget.child,
      };
}
