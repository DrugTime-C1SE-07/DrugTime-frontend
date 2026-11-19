import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

/// A single readable line with an explicit scroll affordance at large text sizes.
class HistoryInlineRow extends StatefulWidget {
  const HistoryInlineRow(
      {super.key, required this.children, this.spread = false});
  final List<Widget> children;
  final bool spread;
  @override
  State<HistoryInlineRow> createState() => _HistoryInlineRowState();
}

class _HistoryInlineRowState extends State<HistoryInlineRow> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: widget.spread
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.children.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.md),
                        widget.children[i],
                      ]
                    ]),
              ),
            ),
          ));
}
