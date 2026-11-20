enum ReminderSoundError {
  unsupportedFormat('Định dạng không hỗ trợ'),
  tooLarge('File quá lớn (tối đa 10 MB)'),
  badDuration('Âm thanh phải dài từ 1 đến 30 giây'),
  undecodable('Không phát được file này');

  const ReminderSoundError(this.message);
  final String message;
}

/// Kiểm file âm thanh người dùng thêm: dung lượng, byte đầu file, thời lượng.
abstract final class ReminderSoundValidator {
  static const maxBytes = 10 * 1024 * 1024;
  static const minDurationMs = 1000;
  static const maxDurationMs = 30000;

  /// Đuôi file suy từ byte đầu (không tin đuôi người dùng đặt); null nếu không hỗ trợ.
  static String? formatOf(List<int> head) {
    bool at(int offset, String ascii) =>
        head.length >= offset + ascii.length &&
        ascii.codeUnits.indexed.every((e) => head[offset + e.$1] == e.$2);

    if (at(0, 'ID3')) return 'mp3';
    if (at(4, 'ftyp')) return 'm4a';
    if (at(0, 'OggS')) return 'ogg';
    if (at(0, 'RIFF') && at(8, 'WAVE')) return 'wav';
    if (head.length >= 2 && head[0] == 0xFF) {
      final b = head[1];
      if (b & 0xF6 == 0xF0) return 'aac'; // ADTS: sync 12 bit, layer 00
      if (b & 0xE0 == 0xE0 && (b >> 1) & 0x3 != 0) {
        return 'mp3'; // MPEG frame sync
      }
    }
    return null;
  }

  static ReminderSoundError? checkFile({
    required int size,
    required List<int> head,
  }) {
    if (size > maxBytes) return ReminderSoundError.tooLarge;
    if (formatOf(head) == null) return ReminderSoundError.unsupportedFormat;
    return null;
  }

  /// [durationMs] null nghĩa là thiết bị không giải mã được file.
  static ReminderSoundError? checkDuration(int? durationMs) {
    if (durationMs == null) return ReminderSoundError.undecodable;
    if (durationMs < minDurationMs || durationMs > maxDurationMs) {
      return ReminderSoundError.badDuration;
    }
    return null;
  }
}
