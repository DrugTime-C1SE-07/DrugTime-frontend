import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';

/// Ô nhập số điện thoại theo thiết kế `field/phone` và `Input/phone`:
/// - Rộng 327px, Cao 73px
/// - Label: 13px / line-height 19px [AppColors.ink]
/// - Khung nhập: Cao 48px, viền 1px [AppColors.border], bo góc 8px, nền [AppColors.surface]
/// - Tiền tố: cờ Việt Nam ([VietnamFlag], 22×15) + '+84' (15px / line-height 22px [AppColors.ink])
/// - Đường phân cách: 1px x 22px [AppColors.border]
/// - Placeholder: '090 123 4567'
class PhoneInputField extends StatefulWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.errorMessage,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? errorMessage;
  final bool enabled;

  @override
  State<PhoneInputField> createState() => _PhoneInputFieldState();
}

class _PhoneInputFieldState extends State<PhoneInputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // field-label
          const Text(
            'Số điện thoại',
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
              height: 19.0 / 15.0,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6.0),

          // Input/phone container
          Focus(
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: Container(
              width: double.infinity,
              height: 58.0,
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F6),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: widget.errorMessage != null
                      ? AppColors.danger
                      : (_focused ? AppColors.brand : AppColors.border),
                  width: 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // prefix: cờ Việt Nam + mã quốc gia
                  const VietnamFlag(),
                  const SizedBox(width: 6.0),
                  const Text(
                    '+84',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w400,
                      height: 22.0 / 15.0,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // divider (1px x 22px)
                  Container(
                    width: 1.0,
                    height: 22.0,
                    color: AppColors.border,
                  ),
                  const SizedBox(width: 8.0),

                  // text field
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled,
                      onChanged: widget.onChanged,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                        _VietnamesePhoneFormatter(),
                      ],
                      style: const TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w400,
                        height: 22.0 / 15.0,
                        color: AppColors.ink,
                      ),
                      decoration: const InputDecoration(
                        filled: false,
                        hintText: '912 345 678',
                        hintStyle: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w400,
                          height: 22.0 / 15.0,
                          color: AppColors.inkMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.errorMessage case final msg?) ...[
            const SizedBox(height: 4.0),
            Text(
              msg,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                height: 17.0 / 11.5,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tự động chèn dấu cách khi nhập số điện thoại Việt Nam: 090 123 4567
class _VietnamesePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Cờ Việt Nam vẽ bằng code (nền đỏ, sao vàng 5 cánh). Không dùng emoji 🇻🇳 vì
/// trên một số máy emoji cờ hiện thành hai chữ "VN".
class VietnamFlag extends StatelessWidget {
  const VietnamFlag({super.key, this.width = 22.0});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Việt Nam',
      image: true,
      child: CustomPaint(
        size: Size(width, width * 15 / 22),
        painter: const _VietnamFlagPainter(),
      ),
    );
  }
}

class _VietnamFlagPainter extends CustomPainter {
  const _VietnamFlagPainter();

  static const _red = Color(0xFFDA251D);
  static const _yellow = Color(0xFFFFCD00);

  @override
  void paint(Canvas canvas, Size size) {
    final flag = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.height * .2));
    canvas.drawRRect(flag, Paint()..color = _red);

    // sao 5 cánh: bán kính ngoài = 0,3 chiều cao cờ, tâm giữa cờ
    final c = size.center(Offset.zero);
    final outer = size.height * .3, inner = outer * .382;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(star..close(), Paint()..color = _yellow);

    canvas.drawRRect(
        flag,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6
          ..color = const Color(0x33000000));
  }

  @override
  bool shouldRepaint(_VietnamFlagPainter oldDelegate) => false;
}
