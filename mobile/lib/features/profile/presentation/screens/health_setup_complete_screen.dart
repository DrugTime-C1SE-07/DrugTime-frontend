import 'package:flutter/material.dart';

import '../../domain/entities/health_setup.dart';
import '../widgets/health_setup_form.dart';

class HealthSetupCompleteScreen extends StatelessWidget {
  const HealthSetupCompleteScreen({
    super.key,
    required this.snapshot,
    required this.allergens,
    required this.conditions,
    required this.onHome,
  });

  final HealthSetupSnapshot snapshot;
  final List<HealthSetupOption<String>> allergens;
  final List<HealthSetupOption<int>> conditions;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: healthSetupPaper,
        bottomNavigationBar:
            HealthSetupActionBar(label: 'Vào ứng dụng', onPressed: onHome),
        body: Stack(
          children: [
            const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 412,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xffcaeae4), healthSetupPaper],
                )))),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(builder: (context, box) {
                final compact = box.maxHeight < 600;
                final gap = compact ? 28.0 : 76.0;
                final mascotFrame = compact ? 144.0 : 190.0;
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20, gap, 20, 26),
                  children: [
                    Center(
                        child: Container(
                      width: mascotFrame,
                      height: mascotFrame,
                      decoration: const BoxDecoration(
                          color: Color(0xa3ffffff), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Image.asset(
                          'assets/images/health_setup/mascot.png',
                          width: compact ? 108 : 142,
                          height: compact ? 98 : 129,
                          excludeFromSemantics: true),
                    )),
                    SizedBox(height: gap),
                    const Text('Đã lưu hồ sơ sức khỏe',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: healthSetupInk,
                            fontSize: 28,
                            height: 1.25,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    const Text('Bạn có thể cập nhật hồ sơ sau.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: healthSetupMuted, fontSize: 16)),
                    SizedBox(height: compact ? 24 : 50),
                    DecoratedBox(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: healthSetupBorder)),
                      child: Column(children: [
                        _row(
                            Icons.warning_amber_rounded,
                            const Color(0xffb45c0d),
                            'Dị ứng',
                            healthSetupSummary(snapshot.allergies, allergens,
                                'Không có dị ứng đã biết')),
                        const Divider(
                            height: 1, indent: 52, color: healthSetupBorder),
                        _row(
                            Icons.favorite_border,
                            const Color(0xff7450bc),
                            'Bệnh nền',
                            healthSetupSummary(snapshot.conditions, conditions,
                                'Không có bệnh nền đã biết')),
                      ]),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      );

  Widget _row(IconData icon, Color color, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: const TextStyle(color: healthSetupMuted)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: healthSetupInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ])),
        ]),
      );
}
