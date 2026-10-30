import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/capture_models.dart';

/// S07c, frame 51:5431. It only returns an explicitly selected candidate.
class CaptureConfirmationScreen extends StatefulWidget {
  const CaptureConfirmationScreen(
      {super.key,
      required this.candidates,
      required this.onConfirm,
      required this.onManual,
      required this.onRescan,
      this.photo,
      this.error,
      this.onRetry});
  final List<CaptureCandidate> candidates;
  final ValueChanged<CaptureCandidate> onConfirm;
  final VoidCallback onManual, onRescan;
  final VoidCallback? onRetry;
  final Uint8List? photo;
  final String? error;
  @override
  State<CaptureConfirmationScreen> createState() =>
      _CaptureConfirmationScreenState();
}

class _CaptureConfirmationScreenState extends State<CaptureConfirmationScreen> {
  String? _selected;
  @override
  void didUpdateWidget(CaptureConfirmationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A fresh result always requires review, even when its id is unchanged.
    if (!identical(oldWidget.candidates, widget.candidates) ||
        oldWidget.error != widget.error) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected =
        widget.candidates.where((c) => c.id == _selected).firstOrNull;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Kiểm tra thuốc'),
            leading: IconButton(
                tooltip: 'Quay lại chụp ảnh',
                onPressed: widget.onRescan,
                icon: const Icon(Icons.arrow_back))),
        body: SafeArea(
            top: false,
            child: Column(children: [
              Expanded(
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.brandTint,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Icon(Icons.fact_check_outlined,
                              size: 20, color: AppColors.brand),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text('Đối chiếu tên và hàm lượng',
                                  style: AppTextStyles.captionStrong))
                        ])),
                    const SizedBox(height: 20),
                    Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                              width: 64,
                              height: 64,
                              color: AppColors.surfaceMuted,
                              child: widget.photo == null
                                  ? const Icon(Icons.inventory_2_outlined,
                                      color: AppColors.inkMuted)
                                  : Image.memory(widget.photo!,
                                      fit: BoxFit.cover,
                                      excludeFromSemantics: true))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Ảnh bao bì',
                                style: AppTextStyles.bodyStrong),
                            TextButton(
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft),
                                onPressed: widget.onRescan,
                                child: const Text('Chụp lại')),
                          ])),
                    ]),
                    const SizedBox(height: 24),
                    if (widget.error != null || widget.candidates.isEmpty) ...[
                      const SizedBox(height: 24),
                      Icon(
                          widget.error != null
                              ? Icons.wifi_off_outlined
                              : Icons.search_off_outlined,
                          size: 48,
                          color: AppColors.inkMuted),
                      const SizedBox(height: 16),
                      Semantics(
                          liveRegion: true,
                          child: Text(widget.error ?? 'Chưa tìm thấy thuốc',
                              style: AppTextStyles.heading,
                              textAlign: TextAlign.center)),
                      const SizedBox(height: 8),
                      const Text('Bạn có thể chụp lại hoặc tìm thủ công.',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center),
                      if (widget.onRetry != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: OutlinedButton(
                                onPressed: widget.onRetry,
                                child: const Text('Thử lại'))),
                    ] else ...[
                      Text(
                          widget.candidates.length == 1
                              ? 'Thuốc gợi ý'
                              : 'Chọn thuốc đúng với bao bì',
                          style: AppTextStyles.heading),
                      const SizedBox(height: 12),
                      for (final candidate in widget.candidates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                              selected: _selected == candidate.id,
                              button: true,
                              label:
                                  'Chọn ${candidate.name}, ${candidate.strength}',
                              child: Material(
                                  color: _selected == candidate.id
                                      ? AppColors.brandTint
                                      : AppColors.surface,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: _selected == candidate.id
                                              ? AppColors.brand
                                              : AppColors.border,
                                          width: _selected == candidate.id
                                              ? 1.5
                                              : 1)),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                      onTap: () => setState(
                                          () => _selected = candidate.id),
                                      child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                    Icons.medication_outlined,
                                                    color: AppColors.brand),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                      Text(candidate.name,
                                                          style: AppTextStyles
                                                              .bodyStrong),
                                                      const SizedBox(height: 4),
                                                      Text(candidate.strength,
                                                          style: AppTextStyles
                                                              .body),
                                                      const SizedBox(height: 4),
                                                      Text(candidate.ingredient,
                                                          style: AppTextStyles
                                                              .caption),
                                                      if (candidate
                                                              .registration !=
                                                          null)
                                                        Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 8),
                                                            child: Text(
                                                                'SĐK ${candidate.registration}',
                                                                style: AppTextStyles
                                                                    .caption)),
                                                    ])),
                                                const SizedBox(width: 8),
                                                Icon(
                                                    _selected == candidate.id
                                                        ? Icons.check_circle
                                                        : Icons
                                                            .radio_button_unchecked,
                                                    color: _selected ==
                                                            candidate.id
                                                        ? AppColors.brand
                                                        : AppColors.inkMuted),
                                              ]))))),
                        ),
                      const SizedBox(height: 8),
                      const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: AppColors.inkMuted),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    'Chỉ tiếp tục khi thông tin khớp bao bì.',
                                    style: AppTextStyles.caption))
                          ]),
                    ],
                  ])),
              Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.border))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                            height: 56,
                            child: FilledButton(
                                onPressed:
                                    selected == null || widget.error != null
                                        ? null
                                        : () => widget.onConfirm(selected),
                                child: const Text('Xác nhận thuốc'))),
                        TextButton(
                            onPressed: widget.onManual,
                            child: const Text('Nhập thủ công')),
                      ])),
            ])));
  }
}
