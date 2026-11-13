import 'package:flutter/material.dart';

import '../../../../core/utils/app_assets.dart';
import 'floating_pills.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader(
      {super.key, this.heading = 'Đăng nhập', this.subheading = ''});
  final String heading;
  final String subheading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(top: -120, right: -110, child: _circle(300)),
          Positioned(top: 150, left: -90, child: _circle(220)),
          Center(
              child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                const SizedBox(height: 30),
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .13),
                            shape: BoxShape.circle),
                        child: Image.asset(
                            'assets/icons/login-mascot-figma.png',
                            fit: BoxFit.contain,
                            excludeFromSemantics: true),
                      ),
                      const SizedBox(height: 10),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(AppAssets.logo,
                                    width: 40, height: 40)),
                            const SizedBox(width: 10),
                            const Text('DrugTime',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800)),
                          ]),
                      const Text('Trợ lý nhắc uống thuốc của bạn',
                          style: TextStyle(
                              color: Color(0xFFCFE7E3), fontSize: 14)),
                    ],
                  ))),
          const Positioned.fill(child: FloatingPills()),
        ],
      ),
    );
  }

  Widget _circle(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)),
      );
}
