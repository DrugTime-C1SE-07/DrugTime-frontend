import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Ô nhập email cho màn hình đăng nhập:
/// - Rộng 327px, Cao 73px
/// - Label: 13px / line-height 19px [AppColors.ink]
/// - Khung nhập: Cao 48px, viền 1px [AppColors.border], bo góc 8px, nền [AppColors.surface]
class EmailInputField extends StatefulWidget {
  const EmailInputField({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorMessage,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorMessage;
  final bool enabled;

  @override
  State<EmailInputField> createState() => _EmailInputFieldState();
}

class _EmailInputFieldState extends State<EmailInputField> {
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
            'Email',
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.w600,
              height: 19.0 / 15.0,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6.0),

          // Input container
          Focus(
            onFocusChange: (focused) => setState(() => _focused = focused),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 58),
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
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: widget.controller,
                enabled: widget.enabled,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w400,
                  height: 22.0 / 15.0,
                  color: AppColors.ink,
                ),
                decoration: const InputDecoration(
                  filled: false,
                  hintText: 'ten@email.com',
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
