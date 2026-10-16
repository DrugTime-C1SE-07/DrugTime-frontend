import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Geometry is defined by each exported Figma SVG; callers provide its slot only.
class ProfileIcon extends StatelessWidget {
  const ProfileIcon(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/icons/profile/$name.svg',
          excludeFromSemantics: true);
}
