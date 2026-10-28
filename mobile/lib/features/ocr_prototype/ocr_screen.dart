import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import 'ocr_controller.dart';
import 'ocr_models.dart';

class OcrPrototypeScreen extends StatefulWidget {
  const OcrPrototypeScreen(
      {super.key, required this.controller, required this.exporter});
  final OcrController controller;
  final OcrExporter exporter;
  @override
  State<OcrPrototypeScreen> createState() => _OcrPrototypeScreenState();
}

class _OcrPrototypeScreenState extends State<OcrPrototypeScreen> {
  final _fields = <String, TextEditingController>{
    for (final key in [
      'imageId',
      'platform',
      'deviceModel',
      'osVersion',
      'appRevision',
      'nativeSdkVersion'
    ])
      key: TextEditingController(),
  };
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _share(OcrRun run) => Builder(
      builder: (context) => TextButton(
          key: ValueKey('export-${run.id}'),
          onPressed: widget.controller.busy
              ? null
              : () {
                  final box = context.findRenderObject()! as RenderBox;
                  widget.controller.export(run, widget.exporter,
                      box.localToGlobal(Offset.zero) & box.size);
                },
          child: const Text('Xuất JSON')));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Thử nghiệm OCR ML Kit')),
      body: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            if (!c.supported) {
              return const Center(
                  child: Text('Prototype OCR chỉ hỗ trợ Android.'));
            }
            const labels = {
              'imageId': 'Mã ảnh trong bộ dữ liệu',
              'platform': 'Nền tảng (Android)',
              'deviceModel': 'Model thiết bị',
              'osVersion': 'Phiên bản OS',
              'appRevision': 'Revision bản build',
              'nativeSdkVersion': 'Native SDK từ lock/build evidence'
            };
            return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const Text(
                      'Chỉ thử ảnh bao bì thuốc. Kết quả OCR chưa được xác minh, không dùng để quyết định dùng thuốc.'),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                      key: const Key('pick-image'),
                      onPressed: c.busy || (c.result != null && !c.saved)
                          ? null
                          : c.pick,
                      child: const Text('Chọn ảnh có sẵn')),
                  if (c.image != null)
                    Image.file(File(c.image!),
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text(
                            'Không xem được ảnh; hãy chọn ảnh khác.')),
                  for (final entry in labels.entries)
                    Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: TextField(
                            key: ValueKey(entry.key),
                            controller: _fields[entry.key],
                            enabled: !c.busy,
                            decoration:
                                InputDecoration(labelText: entry.value))),
                  const Text(
                      'Xác nhận thông tin thiết bị/build ở trên trước mỗi lần chạy.'),
                  FilledButton(
                      key: const Key('run-ocr'),
                      onPressed: c.busy || (c.result != null && !c.saved)
                          ? null
                          : () => c.run(_fields['imageId']!.text, {
                                for (final entry in _fields.entries)
                                  if (entry.key != 'imageId')
                                    entry.key: entry.value.text
                              }),
                      child: const Text('Chạy OCR')),
                  if (c.busy) const LinearProgressIndicator(),
                  if (c.message != null)
                    Semantics(liveRegion: true, child: Text(c.message!)),
                  if (c.result case final run?) ...[
                    Text(
                        '${run.status} · ${run.elapsedMs} ms · ${run.createdAt}'),
                    SelectableText(run.rawText.isEmpty
                        ? '(Không có raw text)'
                        : run.rawText),
                    Text(c.saved
                        ? 'Đã lưu trên thiết bị · ${run.id}'
                        : 'Chưa lưu'),
                    if (!c.saved)
                      TextButton(
                          key: const Key('retry-save'),
                          onPressed: c.busy ? null : c.retrySave,
                          child: const Text('Lưu lại')),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Lịch sử trên thiết bị'),
                  for (final run in c.history)
                    ListTile(
                        title: Text('${run.imageId} · ${run.status}'),
                        subtitle: SelectableText('${run.id}\n${run.rawText}'),
                        trailing: _share(run)),
                ]);
          }));
}
