import 'package:flutter/services.dart';

import 'package:drugtime_mobile/core/notification/reminder_sound.dart';

/// File người dùng chọn, đã copy vào bộ nhớ tạm của app.
class PickedAudio {
  const PickedAudio(
      {required this.path, required this.size, required this.head});
  final String path;
  final int size;
  final List<int> head;
}

/// Phần Android native của âm thanh nhắc (`ReminderSoundChannel.kt`).
abstract class ReminderSoundNative {
  Future<int> sdkInt();

  /// Mở bộ chọn file; null khi người dùng hủy.
  Future<PickedAudio?> pick();

  /// Thời lượng (ms); null khi không giải mã được.
  Future<int?> probeDurationMs(String path);

  /// Chuyển file tạm vào thư mục riêng của app và chèn bản MediaStore tên trung tính.
  Future<({String path, String uri})> commit(
      {required String tempPath,
      required String id,
      required String ext,
      required int number});

  Future<void> discard(String tempPath);
  Future<void> delete({required String path, required String uri});
  Future<bool> exists({required String path, required String uri});
  Future<void> play(ReminderSound sound);
  Future<void> stop();
  Future<void> openSoundSettings();

  /// Gọi khi một lượt nghe thử phát hết.
  set onPreviewDone(void Function()? callback);
}

class MethodChannelReminderSoundNative implements ReminderSoundNative {
  MethodChannelReminderSoundNative() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'previewDone') _onPreviewDone?.call();
    });
  }

  static const _channel =
      MethodChannel('vn.drugtime.drugtime_mobile/reminder_sound');
  void Function()? _onPreviewDone;

  @override
  set onPreviewDone(void Function()? callback) => _onPreviewDone = callback;

  @override
  Future<int> sdkInt() async => await _channel.invokeMethod<int>('sdkInt') ?? 0;

  @override
  Future<PickedAudio?> pick() async {
    final map = await _channel.invokeMapMethod<String, Object?>('pick');
    if (map == null) return null;
    return PickedAudio(
      path: map['path']! as String,
      size: map['size']! as int,
      head: map['head']! as Uint8List,
    );
  }

  @override
  Future<int?> probeDurationMs(String path) =>
      _channel.invokeMethod<int>('probe', {'path': path});

  @override
  Future<({String path, String uri})> commit(
      {required String tempPath,
      required String id,
      required String ext,
      required int number}) async {
    final map = await _channel.invokeMapMethod<String, String>(
        'commit', {'path': tempPath, 'id': id, 'ext': ext, 'number': number});
    return (path: map!['path']!, uri: map['uri']!);
  }

  @override
  Future<void> discard(String tempPath) =>
      _channel.invokeMethod<void>('discard', {'path': tempPath});

  @override
  Future<void> delete({required String path, required String uri}) =>
      _channel.invokeMethod<void>('delete', {'path': path, 'uri': uri});

  @override
  Future<bool> exists({required String path, required String uri}) async =>
      await _channel.invokeMethod<bool>('exists', {'path': path, 'uri': uri}) ??
      false;

  @override
  Future<void> play(ReminderSound sound) => _channel
      .invokeMethod<void>('play', {'raw': sound.rawName, 'uri': sound.uri});

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> openSoundSettings() =>
      _channel.invokeMethod<void>('openSoundSettings');
}
