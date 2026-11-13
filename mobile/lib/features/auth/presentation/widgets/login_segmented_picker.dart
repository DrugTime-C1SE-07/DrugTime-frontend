import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/login_method.dart';

class LoginSegmentedPicker extends StatelessWidget {
  const LoginSegmentedPicker({
    super.key,
    required this.selectedMethod,
    required this.onMethodChanged,
  });

  final LoginMethod selectedMethod;
  final ValueChanged<LoginMethod>? onMethodChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _tab(LoginMethod.phone, 'Số điện thoại'),
            const SizedBox(width: 4),
            _tab(LoginMethod.email, 'Email'),
          ],
        ),
      ),
    );
  }

  Widget _tab(LoginMethod method, String label) {
    final selected = selectedMethod == method;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: selected ? AppColors.surface : Colors.transparent,
            foregroundColor: selected ? AppColors.brand : AppColors.inkMuted,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          ),
          onPressed:
              onMethodChanged == null ? null : () => onMethodChanged!(method),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  method == LoginMethod.phone
                      ? LucideIcons.phone
                      : LucideIcons.mail,
                  size: 18),
              const SizedBox(width: 6),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
  }
}
