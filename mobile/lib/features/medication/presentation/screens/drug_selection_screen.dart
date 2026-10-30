import 'package:flutter/material.dart';

import '../../domain/entities/medication.dart';
import '../widgets/drug_catalog_sheet.dart';
import '../widgets/drug_selection_panel.dart';

Future<DrugCatalogItem?> showDrugSelectionScreen(
  BuildContext context, {
  required List<DrugCatalogItem> candidates,
  required DrugSelectionSource source,
  required CatalogSearch search,
}) =>
    Navigator.of(context).push<DrugCatalogItem>(MaterialPageRoute(
      builder: (_) => DrugSelectionScreen(
          candidates: candidates, source: source, search: search),
    ));

class DrugSelectionScreen extends StatefulWidget {
  const DrugSelectionScreen({
    super.key,
    required this.candidates,
    required this.source,
    required this.search,
  });

  final List<DrugCatalogItem> candidates;
  final DrugSelectionSource source;
  final CatalogSearch search;

  @override
  State<DrugSelectionScreen> createState() => _DrugSelectionScreenState();
}

class _DrugSelectionScreenState extends State<DrugSelectionScreen> {
  bool _openingSearch = false;
  bool _returned = false;

  void _confirm(DrugCatalogItem item) {
    if (_returned ||
        !mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return;
    }
    _returned = true;
    Navigator.of(context).pop(item);
  }

  Future<void> _manualSearch() async {
    if (_openingSearch || _returned) return;
    _openingSearch = true;
    final item = await showDrugCatalogSheet(context,
        search: widget.search, isInUse: (_) => false);
    if (!mounted) return;
    _openingSearch = false;
    if (item != null) _confirm(item);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Xác nhận thông tin'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Hủy')),
          ],
        ),
        body: SafeArea(
          child: DrugSelectionPanel(
            candidates: widget.candidates,
            source: widget.source,
            onConfirm: _confirm,
            onManualSearch: _manualSearch,
          ),
        ),
      );
}
