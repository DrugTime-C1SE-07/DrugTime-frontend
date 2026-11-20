import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/api/api_exception.dart';
import '../../data/account_deletion_repository.dart';
import '../../../auth/presentation/state/auth_controller.dart';
import '../../../auth/presentation/widgets/otp_pin_input.dart';
import '../../../profile/presentation/state/profile_controller.dart';
import '../../../../shared/widgets/mascot/mascot_controller.dart';
import '../../../../shared/widgets/mascot/mascot_view.dart';

const _green = Color(0xff01554f), _red = Color(0xffb91c1c);
const _ink = Color(0xff211d1d), _muted = Color(0xff5b6169);

class AccountDeletionScope extends InheritedWidget {
  const AccountDeletionScope(
      {super.key, required this.repository, required super.child});
  final AccountDeletionRepository? repository;
  static AccountDeletionRepository? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AccountDeletionScope>()
      ?.repository;
  @override
  bool updateShouldNotify(AccountDeletionScope oldWidget) =>
      repository != oldWidget.repository;
}

/// A failed lookup never opens the app; login itself never cancels a request.
class AccountDeletionGate extends StatefulWidget {
  const AccountDeletionGate({super.key, required this.child});
  final Widget child;
  @override
  State<AccountDeletionGate> createState() => _AccountDeletionGateState();
}

class _AccountDeletionGateState extends State<AccountDeletionGate> {
  String? _token;
  bool _checking = false;
  String? _error;
  PendingAccountDeletion? _pending;
  int _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuthScope.of(context);
    final token =
        auth.isAuthenticated ? auth.currentSession?.accessToken : null;
    if (token == _token) return;
    _token = token;
    _pending = null;
    _error = null;
    _generation++;
    _checking = token != null && AccountDeletionScope.of(context) != null;
    if (_checking) unawaited(_load(_generation));
  }

  Future<void> _load(int generation) async {
    try {
      final pending = await AccountDeletionScope.of(context)!.current();
      if (mounted && generation == _generation) {
        setState(() {
          _pending = pending;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = 'Chưa kiểm tra được trạng thái tài khoản. Vui lòng thử lại.';
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? overlay;
    if (_checking) {
      overlay =
          const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (_error != null) {
      overlay = AccountDeletionScreen(
          statusError: _error,
          onRetry: () {
            setState(() {
              _checking = true;
              _error = null;
            });
            unawaited(_load(_generation));
          });
    } else if (_pending != null) {
      overlay = AccountDeletionScreen(
          pending: _pending, onRestored: () => setState(() => _pending = null));
    }
    // Preserve the Navigator so sign-out can replace its routes even while X7
    // is visible. Offstage hides all underlying pixels/semantics, and both
    // focus and animations stay suspended until the server confirms cancel.
    return Stack(fit: StackFit.expand, children: [
      Offstage(
          offstage: overlay != null,
          child: ExcludeFocus(
              excluding: overlay != null,
              child:
                  TickerMode(enabled: overlay == null, child: widget.child))),
      if (overlay != null) overlay,
    ]);
  }
}

enum DeletionStep { consequences, send, otp, locked, confirm, scheduled }

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen(
      {super.key,
      this.repository,
      this.pending,
      this.onRestored,
      this.statusError,
      this.onRetry,
      this.clock});
  final AccountDeletionRepository? repository;
  final PendingAccountDeletion? pending;
  final VoidCallback? onRestored;
  final String? statusError;
  final VoidCallback? onRetry;
  final DateTime Function()? clock;
  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  DeletionStep _step = DeletionStep.consequences;
  final _pin = TextEditingController();
  final _focus = FocusNode();
  final _otpEntryKey = GlobalKey();
  final _mascot = MascotController();
  Timer? _timer;
  DeletionChallenge? _challenge;
  PendingAccountDeletion? _saved;
  bool _agreed = false, _busy = false;
  String? _error;
  DateTime? _resendAt, _lockedUntil;
  int _failures = 0;
  bool _sendLimited = false;
  DateTime _now() => widget.clock?.call() ?? DateTime.now();
  bool get _returning => widget.pending != null || widget.statusError != null;
  AccountDeletionRepository get _repo =>
      widget.repository ?? AccountDeletionScope.of(context)!;
  int _seconds(DateTime? at) => at == null
      ? 0
      : math.max(0, (at.difference(_now()).inMilliseconds / 1000).ceil());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.viewInsetsOf(context).bottom > 0 && _focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _otpEntryKey.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: .35,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  String _clock(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  String _date(DateTime at) {
    final v = at.toUtc().add(const Duration(hours: 7));
    return '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
  }

  @override
  void initState() {
    super.initState();
    _mascot.play(_returning ? MascotMood.thumbsUp : MascotMood.farewell);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_step == DeletionStep.otp &&
            _challenge != null &&
            _seconds(_challenge!.expiresAt) == 0 &&
            !_busy) {
          _error = 'Mã đã hết hạn';
        }
        if (_step == DeletionStep.locked && _seconds(_lockedUntil) == 0) {
          _step = DeletionStep.send;
          _failures = 0;
          _error = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pin.dispose();
    _focus.dispose();
    _mascot.dispose();
    super.dispose();
  }

  void _go(DeletionStep step) {
    _focus.unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
  }

  Future<void> _call(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      String? code;
      try {
        code = (jsonDecode(e.message) as Map<String, dynamic>)['detail']
            as String?;
      } catch (_) {}
      setState(() {
        if (e.statusCode == 429) {
          final delay = e.retryAfter;
          if (code == 'deletion_otp_rate_limited' ||
              (delay != null && delay.inSeconds > 60)) {
            _lockedUntil = _now().add(delay ?? const Duration(minutes: 15));
            _sendLimited = code == 'deletion_otp_send_rate_limited';
            _step = DeletionStep.locked;
            _error = null;
          } else {
            _resendAt = _now().add(delay ?? const Duration(seconds: 60));
            _error = 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.';
          }
        } else if (code == 'deletion_otp_invalid') {
          _failures = e.remainingOtpAttempts == null
              ? _failures + 1
              : 5 - e.remainingOtpAttempts!;
          _step = DeletionStep.otp;
          _error = _seconds(_challenge?.expiresAt) == 0
              ? 'Mã đã hết hạn'
              : 'Mã không đúng · còn ${math.max(0, 5 - _failures)} lần thử';
          if (e.remainingOtpAttempts == 0 && e.retryAfter != null) {
            _lockedUntil = _now().add(e.retryAfter!);
            _sendLimited = false;
            _step = DeletionStep.locked;
            _error = null;
          }
        } else if (code == 'verified_email_required') {
          _error = 'Vui lòng xác minh email trong hồ sơ trước khi tiếp tục.';
        } else if (code == 'deletion_request_due') {
          _error = 'Yêu cầu đã đến hạn xử lý và không thể hủy.';
        } else {
          _error = 'Chưa thể hoàn tất. Kiểm tra kết nối và thử lại.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa thể hoàn tất. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _call(() async {
        final challenge = await _repo.issue();
        if (!mounted) return;
        setState(() {
          _challenge = challenge;
          _resendAt = _now().add(const Duration(seconds: 60));
          _pin.clear();
          _step = DeletionStep.otp;
        });
        _focus.requestFocus();
      });
  Future<void> _verify() => _call(() async {
        await _repo.verify(_challenge!.id, _pin.text);
        if (mounted) _go(DeletionStep.confirm);
      });
  Future<void> _create() => _call(() async {
        // Repeating the same challenge after a timeout returns the saved deadline.
        final saved = await _repo.create(_challenge!.id);
        if (mounted) {
          setState(() {
            _saved = saved;
            _pin.clear();
            _step = DeletionStep.scheduled;
          });
        }
      });
  Future<void> _cancel() => _call(() async {
        await _repo.cancel();
        if (mounted) widget.onRestored?.call();
      });
  Future<void> _leave() => _call(() async {
        await AuthScope.read(context).signOut();
      });
  void _back() {
    if (_busy || _returning || _step == DeletionStep.scheduled) return;
    if (_step == DeletionStep.consequences || _step == DeletionStep.locked) {
      Navigator.of(context).pop();
    } else {
      _go(switch (_step) {
        DeletionStep.send => DeletionStep.consequences,
        DeletionStep.confirm => DeletionStep.otp,
        _ => DeletionStep.send,
      });
    }
  }

  Text _text(String value,
          {double size = 15,
          double? lineHeight,
          Color color = _muted,
          FontWeight weight = FontWeight.w400,
          TextAlign align = TextAlign.center}) =>
      Text(value,
          textAlign: align,
          style: TextStyle(
              fontFamily: 'WelcomeInter',
              fontSize: size,
              height: lineHeight ?? (size >= 26 ? 1.25 : 1.5),
              color: color,
              fontWeight: weight));
  Widget _heading(String title,
          [String? subtitle, double size = 28, double gap = 6]) =>
      Column(children: [
        _text(title, size: size, color: _ink, weight: FontWeight.w700),
        if (subtitle != null) ...[
          SizedBox(height: gap),
          _text(subtitle,
              size: _step == DeletionStep.consequences ||
                      _step == DeletionStep.locked
                  ? 16
                  : 15)
        ],
      ]);
  Widget _iconText(IconData icon, String text,
          {double size = 15,
          double? lineHeight,
          Color color = _muted,
          FontWeight weight = FontWeight.w400}) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: size >= 26 ? 28 : 20, color: color),
        const SizedBox(width: 8),
        Flexible(
            child: _text(text,
                size: size,
                lineHeight: lineHeight,
                color: color,
                weight: weight)),
      ]);
  Widget _card(Widget child,
          {Color color = const Color(0xfff5f7f6), double padding = 16}) =>
      Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(20)),
          child: child);
  Widget _row(IconData icon, String title, String? subtitle, Color tile,
          {bool kept = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: tile, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon,
                    size: 24,
                    color: icon == LucideIcons.pill
                        ? const Color(0xff006694)
                        : icon == LucideIcons.utensils
                            ? const Color(0xffb45309)
                            : icon == LucideIcons.heart
                                ? const Color(0xffbe123c)
                                : const Color(0xff6651b2))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _text(title,
                      size: 16,
                      color: _ink,
                      weight: FontWeight.w600,
                      align: TextAlign.left),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    _text(subtitle, size: 14, align: TextAlign.left),
                  ],
                ])),
            if (kept) const SizedBox(width: 12),
            if (kept)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color(0xffe7f5e9),
                      borderRadius: BorderRadius.circular(20)),
                  child: _text('Còn nguyên',
                      size: 13,
                      color: const Color(0xff1e7a45),
                      weight: FontWeight.w600)),
          ]));
  Widget _contents() {
    if (widget.statusError != null) {
      return _heading('Trạng thái yêu cầu', widget.statusError, 26);
    }
    final profile = context
        .dependOnInheritedWidgetOfExactType<ProfileScope>()
        ?.notifier
        ?.profile;
    final email = profile?.email;
    final masked = email != null && email.contains('@')
        ? '${email.substring(0, 1)}•••@${email.split('@').last}'
        : 'Email đã xác minh';
    if (_returning) {
      return Column(children: [
        _heading('Yêu cầu đang chờ xử lý',
            'Ngày dự kiến: ${_date(widget.pending!.scheduledAt)}', 26),
        const SizedBox(height: 16),
        _card(
            Column(children: [
              _row(LucideIcons.pill, 'Thuốc & lịch nhắc', null,
                  const Color(0xffdceefb),
                  kept: true),
              const SizedBox(height: 4),
              _row(LucideIcons.users, 'Người thân', null,
                  const Color(0xffede7fb),
                  kept: true),
              const SizedBox(height: 4),
              _row(LucideIcons.heart, 'Hồ sơ sức khỏe', null,
                  const Color(0xffffe4e6),
                  kept: true),
            ]),
            padding: 8),
      ]);
    }
    return switch (_step) {
      DeletionStep.consequences => Column(children: [
          _heading('Xóa tài khoản?', 'Khi yêu cầu được xử lý, các mục sẽ mất:'),
          const SizedBox(height: 16),
          _card(
              Column(children: [
                _row(LucideIcons.pill, 'Thuốc & lịch nhắc',
                    'Thuốc và lịch sử uống của bạn', const Color(0xffdceefb)),
                const SizedBox(height: 4),
                _row(
                    LucideIcons.users,
                    'Kết nối người thân',
                    'Người thân sẽ không theo dõi được',
                    const Color(0xffede7fb)),
                const SizedBox(height: 4),
                _row(LucideIcons.utensils, 'Bữa ăn Dumi & hồ sơ sức khỏe',
                    'Dị ứng, bệnh nền, món đã chọn', const Color(0xfffdebd9)),
              ]),
              padding: 8),
        ]),
      DeletionStep.send => Column(children: [
          _heading(
              'Xác nhận đó là bạn', 'Mã 6 số sẽ gửi tới email đã xác minh'),
          const SizedBox(height: 16),
          _card(Row(children: [
            const Icon(LucideIcons.mail, color: _green, size: 32),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _text(masked, size: 20, color: _ink, weight: FontWeight.w600),
                  _text('Email đã xác minh', size: 14)
                ])),
            const Icon(LucideIcons.badgeCheck, color: _green)
          ])),
          const SizedBox(height: 16),
          _iconText(LucideIcons.clock, 'Mã có hiệu lực trong 5 phút'),
        ]),
      DeletionStep.otp => Column(children: [
          _heading('Nhập mã xác nhận'),
          const SizedBox(height: 6),
          Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Mã 6 số đã gửi tới '),
                TextSpan(
                    text: masked,
                    style: const TextStyle(
                        color: _ink, fontWeight: FontWeight.w700)),
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'WelcomeInter',
                  fontSize: 17,
                  height: 24 / 17,
                  color: _muted)),
          const SizedBox(height: 18),
          OtpPinInput(
            key: _otpEntryKey,
            inputKey: const Key('deletion-otp'),
            boxKeyPrefix: 'deletion-digit-',
            boxHeight: 60,
            boxRadius: 16,
            emptyColor: const Color(0xfff5f7f6),
            digitStyle: const TextStyle(
              fontFamily: 'WelcomeInter',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
            controller: _pin,
            focusNode: _focus,
            enabled: !_busy,
            hasError: _error?.startsWith('Mã không đúng') == true,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onCompleted: (_) => unawaited(_verify()),
          ),
          const SizedBox(height: 18),
          if (_busy)
            _iconText(LucideIcons.clock, 'Đang xác thực…', size: 17)
          else if (_error != null)
            _text(_error!,
                size: 17,
                color:
                    _error == 'Mã đã hết hạn' ? const Color(0xffb4570f) : _red)
          else
            _iconText(LucideIcons.clock,
                'Gửi lại mã sau ${_clock(_seconds(_resendAt))}',
                size: 17),
          if (!_busy && (_error != null || _seconds(_resendAt) == 0)) ...[
            const SizedBox(height: 18),
            TextButton(
                onPressed: _seconds(_resendAt) == 0 ? _send : null,
                child: Text(_seconds(_resendAt) == 0
                    ? 'Gửi lại mã'
                    : 'Gửi lại mã sau ${_clock(_seconds(_resendAt))}')),
            if (_pin.text.length == 6 && _error != 'Mã đã hết hạn')
              TextButton(onPressed: _verify, child: const Text('Thử lại')),
          ],
        ]),
      DeletionStep.locked => Column(children: [
          _heading(
              'Tạm dừng xác thực',
              _sendLimited
                  ? 'Bạn đã gửi mã quá nhiều lần.'
                  : 'Bạn đã nhập sai mã 5 lần.',
              26,
              14),
          const SizedBox(height: 28),
          _card(
              Column(children: [
                _iconText(LucideIcons.clock, _clock(_seconds(_lockedUntil)),
                    size: 36,
                    lineHeight: 42 / 36,
                    color: const Color(0xffb4570f),
                    weight: FontWeight.w700),
                const SizedBox(height: 12),
                _text('Thời gian chờ còn lại', color: const Color(0xff8a5a1f))
              ]),
              color: const Color(0xfffff4e5),
              padding: 24),
        ]),
      DeletionStep.confirm => Column(children: [
          _heading('Xóa tài khoản này?', null, 26),
          const SizedBox(height: 16),
          _card(Row(children: [
            const CircleAvatar(
                backgroundColor: Color(0xffdceefb),
                child: Icon(LucideIcons.userRound)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  _text(profile?.fullName ?? 'Tài khoản của bạn',
                      size: 18,
                      color: _ink,
                      weight: FontWeight.w600,
                      align: TextAlign.left),
                  _text(masked)
                ]))
          ])),
          const SizedBox(height: 16),
          _card(
              Column(children: [
                _timeline(LucideIcons.circleAlert, 'Trong thời gian chờ',
                    'Tạm dừng người thân xem dữ liệu'),
                _timeline(LucideIcons.calendarClock, 'Sau 30 ngày',
                    'Ngày dự kiến xử lý yêu cầu'),
              ]),
              color: const Color(0xfffdecec)),
          const SizedBox(height: 16),
          _iconText(
              LucideIcons.rotateCcw, 'Dữ liệu được giữ trong thời gian chờ',
              color: _green),
        ]),
      DeletionStep.scheduled => Column(children: [
          _heading('Đã lên lịch xóa', 'Yêu cầu đã ghi nhận. Ngày dự kiến:', 26),
          const SizedBox(height: 16),
          _card(
              Column(children: [
                _text(_date(_saved!.scheduledAt),
                    size: 32, color: _green, weight: FontWeight.w700),
                const SizedBox(height: 12),
                _text('Thời gian chờ: 30 ngày', color: const Color(0xff2f6f67))
              ]),
              color: const Color(0xffe7f3f1)),
          const SizedBox(height: 16),
          _card(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(LucideIcons.info, size: 20, color: _muted),
            const SizedBox(width: 12),
            Expanded(
                child: _text(
                    'Dữ liệu vẫn được giữ. Người thân tạm thời không thể xem dữ liệu sức khỏe của bạn.',
                    align: TextAlign.left))
          ])),
        ]),
    };
  }

  Widget _timeline(IconData icon, String title, String subtitle) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xff7f1d1d)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _text(title,
              size: 16,
              color: const Color(0xff7f1d1d),
              weight: FontWeight.w600,
              align: TextAlign.left),
          _text(subtitle, color: const Color(0xff7f1d1d), align: TextAlign.left)
        ]))
      ]));
  Widget _button(String label, VoidCallback? action, {bool outline = false, Color color = _green}) =>
      SizedBox(
          width: double.infinity,
          height: math.max(
              56, MediaQuery.textScalerOf(context).scale(17) * 2.4 + 12),
          child: ElevatedButton(
              onPressed: _busy ? null : action,
              style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: outline ? Colors.white : color,
                  foregroundColor: outline ? color : Colors.white,
                  disabledBackgroundColor: const Color(0xffd3d8dc),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: outline
                          ? BorderSide(
                              color: color == _green
                                  ? const Color(0xffdedede)
                                  : color)
                          : BorderSide.none),
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(label,
                      style: const TextStyle(
                          fontFamily: 'WelcomeInter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700))));
  Widget _bottom() {
    if (widget.statusError != null) {
      return Row(children: [
        SizedBox(
            width: 112, child: _button('Đăng xuất', _leave, outline: true)),
        const SizedBox(width: 12),
        Expanded(child: _button('Thử lại', widget.onRetry)),
      ]);
    }
    if (_returning) {
      return Row(children: [
        SizedBox(
            width: 112,
            child: _button('Vẫn xóa', _leave, outline: true, color: _red)),
        const SizedBox(width: 12),
        Expanded(child: _button('Đăng nhập lại', _cancel))
      ]);
    }
    return switch (_step) {
      DeletionStep.consequences => Row(children: [
          SizedBox(
              width: 112,
              child: _button('Giữ lại', () => Navigator.of(context).pop(),
                  outline: true)),
          const SizedBox(width: 12),
          Expanded(
              child: _button(
                  'Tiếp tục', _agreed ? () => _go(DeletionStep.send) : null,
                  color: _red))
        ]),
      DeletionStep.send => _button('Gửi mã', _send),
      DeletionStep.confirm => Row(children: [
          SizedBox(
              width: 112,
              child: _button('Hủy', () => Navigator.of(context).pop(),
                  outline: true)),
          const SizedBox(width: 12),
          Expanded(child: _button('Xóa tài khoản', _create, color: _red))
        ]),
      DeletionStep.scheduled => _button('Về màn đăng nhập', _leave),
      DeletionStep.locked =>
        _button('Về Cài đặt', () => Navigator.of(context).pop()),
      DeletionStep.otp => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final otp = !_returning && _step == DeletionStep.otp;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeTopOffset = math.max(0.0, MediaQuery.paddingOf(context).top - 44);
    final progress = _step == DeletionStep.consequences
        ? 1
        : _step == DeletionStep.send || otp || _step == DeletionStep.locked
            ? 2
            : 3;
    return PopScope(
        canPop: !_busy &&
            !_returning &&
            (_step == DeletionStep.consequences ||
                _step == DeletionStep.locked),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: LayoutBuilder(
              builder: (context, box) => Stack(children: [
                    Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 260 + safeTopOffset,
                        child: CustomPaint(painter: _DeletionSky())),
                    if (!keyboardOpen)
                      Positioned(
                          top: (_returning ? 58 : 48) + safeTopOffset,
                          left: 0,
                          right: 0,
                          child: Center(
                              child: IgnorePointer(
                                  child: MascotView(
                                      controller: _mascot,
                                      size: _returning ? 96 : 112,
                                      height: _returning ? 88 : 112,
                                      figmaArtwork: true)))),
                    if (!_returning && _step != DeletionStep.scheduled)
                      Positioned(
                          top: math.max(
                              48, MediaQuery.paddingOf(context).top + 4),
                          left: 20,
                          child: IconButton.filledTonal(
                              onPressed: _busy ? null : _back,
                              style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xffe7f3f1),
                                  fixedSize: const Size(48, 48)),
                              icon: const Icon(LucideIcons.chevronLeft,
                                  color: _green))),
                    Positioned(
                        top: keyboardOpen && otp ? 0 : 196 + safeTopOffset,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(
                                        keyboardOpen && otp ? 0 : 28))),
                            child: Column(children: [
                              Expanded(
                                  child: SingleChildScrollView(
                                      padding: EdgeInsets.fromLTRB(
                                          20,
                                          keyboardOpen && otp
                                              ? math.max(
                                                  100,
                                                  MediaQuery.paddingOf(context)
                                                          .top +
                                                      56)
                                              : 22,
                                          20,
                                          16),
                                      child: Column(children: [
                                        if (!_returning) ...[
                                          Row(
                                              children: List.generate(
                                                  3,
                                                  (i) => Expanded(
                                                      child: Container(
                                                          height: 6,
                                                          margin:
                                                              EdgeInsets.only(
                                                                  right: i < 2
                                                                      ? 8
                                                                      : 0),
                                                          decoration: BoxDecoration(
                                                              color: i <
                                                                      progress
                                                                  ? _green
                                                                  : const Color(
                                                                      0xffd3d8dc),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          3)))))),
                                          SizedBox(
                                              height:
                                                  _step == DeletionStep.locked
                                                      ? 28
                                                      : otp
                                                          ? 18
                                                          : 16)
                                        ],
                                        _contents(),
                                        if (_error != null && !otp) ...[
                                          const SizedBox(height: 12),
                                          Semantics(
                                              liveRegion: true,
                                              child:
                                                  _text(_error!, color: _red))
                                        ],
                                      ]))),
                              if (!_returning &&
                                  _step == DeletionStep.consequences)
                                Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 0, 20, 17),
                                    child: InkWell(
                                        onTap: () =>
                                            setState(() => _agreed = !_agreed),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                                color: _agreed
                                                    ? const Color(0xffe7f3f1)
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: _agreed
                                                        ? _green
                                                        : const Color(
                                                            0xffd3d8dc),
                                                    width: 1.5)),
                                            child: Row(children: [
                                              SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: Transform.scale(
                                                      scale: 4 / 3,
                                                      child: Checkbox(
                                                          value: _agreed,
                                                          onChanged: (v) =>
                                                              setState(() =>
                                                                  _agreed = v!),
                                                          activeColor: _green,
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          3))))),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: _text(
                                                      'Tôi hiểu dữ liệu sẽ bị xóa',
                                                      size: 16,
                                                      color: _ink,
                                                      align: TextAlign.left))
                                            ])))),
                              if (!otp)
                                Container(
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        border: Border(
                                            top: BorderSide(
                                                color: Color(0xffeeeeee)))),
                                    padding: EdgeInsets.fromLTRB(
                                        20,
                                        12,
                                        20,
                                        math.max(
                                            33,
                                            MediaQuery.paddingOf(context)
                                                .bottom)),
                                    child: _bottom()),
                            ]))),
                  ])),
        ));
  }
}

class _DeletionSky extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xff003d39), Color(0xff087d71)])
              .createShader(Offset.zero & s));
    c.drawCircle(Offset(s.width * .93, 30), 150,
        Paint()..color = Colors.white.withValues(alpha: .06));
    c.drawCircle(const Offset(20, 260), 110,
        Paint()..color = Colors.white.withValues(alpha: .05));
    c.drawCircle(Offset(s.width / 2, 109), 55,
        Paint()..color = Colors.white.withValues(alpha: .12));
    for (final (x, y, w, h, a, color)
        in <(double, double, double, double, double, Color)>[
      (23, 99, 56, 22, -.6, const Color(0xffed871f)),
      (306, 100, 48, 19, .5, const Color(0xff7fd8c9)),
      (35, 170, 40, 16, .95, const Color(0xfff5c542)),
      (304, 170, 60, 23, -.35, const Color(0xffed871f)),
      (293, 65, 30, 12, -1.2, const Color(0xffa3d1c9))
    ]) {
      c.save();
      c.translate(x * s.width / 375, y);
      c.rotate(a);
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h), Radius.circular(h / 2));
      c.clipRRect(rect);
      c.drawRRect(rect, Paint()..color = Colors.white);
      c.drawRect(Rect.fromLTWH(0, 0, w / 2, h), Paint()..color = color);
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * .18, 4, w * .62, 3), const Radius.circular(2)),
          Paint()..color = Colors.white.withValues(alpha: .5));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_DeletionSky oldDelegate) => false;
}
