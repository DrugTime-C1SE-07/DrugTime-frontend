import 'package:flutter/material.dart';

import 'health_setup_form.dart';

Future<String?> showHealthSetupCustomSheet(BuildContext context,
        {required bool allergy}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x80465450),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CustomSheet(allergy: allergy),
    );

class _CustomSheet extends StatefulWidget {
  const _CustomSheet({required this.allergy});
  final bool allergy;

  @override
  State<_CustomSheet> createState() => _CustomSheetState();
}

class _CustomSheetState extends State<_CustomSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.allergy ? 'Thêm dị ứng khác' : 'Thêm bệnh nền khác';
    final label = widget.allergy ? 'Tên thuốc hoặc thực phẩm' : 'Tên bệnh nền';
    final hint = widget.allergy ? 'Nhập tên dị ứng' : 'Nhập tên bệnh nền';
    final usable = _name.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 22, 20, MediaQuery.viewInsetsOf(context).bottom + 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    color: healthSetupInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                    color: healthSetupInk, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              maxLength: 120,
              onChanged: (_) => setState(() {}),
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) Navigator.pop(context, text);
              },
              decoration: InputDecoration(
                  hintText: hint,
                  counterText: '',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xffb4bec7))),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffe6f3f1),
                    foregroundColor: healthSetupBrand,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Hủy'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                onPressed:
                    usable ? () => Navigator.pop(context, _name.text) : null,
                style: FilledButton.styleFrom(
                    backgroundColor: healthSetupBrand,
                    disabledBackgroundColor: const Color(0xffe9ebea),
                    disabledForegroundColor: healthSetupMuted,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Thêm'),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}
