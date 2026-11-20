import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/ocr_models.dart';

/// Trạng thái của một bước trong sheet "Đang nhận diện thuốc".
enum RecognitionStepState { done, active, pending }

const _brand = Color(0xFF00534D);
const _brandTint = Color(0xFFE2F1ED);
const _pendingRing = Color(0xFFCDD3D0);
const _ink = Color(0xFF202221);
const _inkMuted = Color(0xFF6B737D);

/// Ba bước nhận diện dùng **chung một kiểu**: cùng kích thước vòng, cùng màu chủ đạo; chỉ khác
/// icon theo trạng thái (đã xong = tick trên nền đặc, đang chạy = vòng quay, chưa tới = vòng
/// viền). Nhận xét 1 của adhoc-20261120-add-medication-ux.
class RecognitionSteps extends StatelessWidget {
  const RecognitionSteps({super.key, required this.stage});

  final OcrStage stage;

  /// Đọc chữ xong khi đã sang giai đoạn đối chiếu (hoặc có kết quả).
  bool get _readDone =>
      stage == OcrStage.matching || stage == OcrStage.result;

  List<(String, RecognitionStepState)> get steps => [
        ('Đã chụp ảnh vỏ thuốc', RecognitionStepState.done),
        (
          _readDone ? 'Đã đọc chữ trên vỏ' : 'Đang đọc chữ trên vỏ',
          _readDone ? RecognitionStepState.done : RecognitionStepState.active,
        ),
        (
          stage == OcrStage.result
              ? 'Đã đối chiếu danh mục thuốc'
              : _readDone
                  ? 'Đang đối chiếu danh mục thuốc'
                  : 'Đối chiếu danh mục thuốc',
          stage == OcrStage.result
              ? RecognitionStepState.done
              : _readDone
                  ? RecognitionStepState.active
                  : RecognitionStepState.pending,
        ),
      ];

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (label, state) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RecognitionStepRow(label: label, state: state),
          ),
      ]);
}

/// Giá trị thanh tiến trình theo giai đoạn thật của OCR, không cố định.
double recognitionProgress(OcrStage stage) => switch (stage) {
      OcrStage.preparing => 1 / 3,
      OcrStage.recognizing => 1 / 3,
      OcrStage.matching => 2 / 3,
      OcrStage.result => 1,
      OcrStage.failure || OcrStage.closed => 1 / 3,
    };

class RecognitionStepRow extends StatelessWidget {
  const RecognitionStepRow({super.key, required this.label, required this.state});

  static const double markSize = 32;

  final String label;
  final RecognitionStepState state;

  @override
  Widget build(BuildContext context) {
    final mark = switch (state) {
      RecognitionStepState.done => Container(
          key: const Key('recognition-mark-done'),
          decoration: const BoxDecoration(color: _brand, shape: BoxShape.circle),
          child: const Icon(LucideIcons.check, size: 17, color: Colors.white),
        ),
      // Icon tĩnh: chuyển động của sheet do linh vật đảm nhận (animation hữu hạn).
      RecognitionStepState.active => Container(
          key: const Key('recognition-mark-active'),
          decoration: const BoxDecoration(color: _brandTint, shape: BoxShape.circle),
          child: const Icon(LucideIcons.loaderCircle, size: 17, color: _brand),
        ),
      RecognitionStepState.pending => Container(
          key: const Key('recognition-mark-pending'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _pendingRing, width: 2),
          ),
        ),
    };
    return Semantics(
      label: '$label, ${switch (state) {
        RecognitionStepState.done => 'đã xong',
        RecognitionStepState.active => 'đang chạy',
        RecognitionStepState.pending => 'chưa tới',
      }}',
      excludeSemantics: true,
      child: Row(children: [
        SizedBox.square(dimension: markSize, child: mark),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: state == RecognitionStepState.pending ? _inkMuted : _ink,
              fontWeight: state == RecognitionStepState.active
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ]),
    );
  }
}
