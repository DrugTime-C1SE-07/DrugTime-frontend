import 'package:flutter_test/flutter_test.dart';

import 'package:drugtime_mobile/core/notification/reminder_sound_validator.dart';

List<int> ascii(String s, [int pad = 16]) =>
    [...s.codeUnits, ...List.filled(pad, 0)];

void main() {
  group('formatOf__AC4', () {
    final cases = <String, List<int>>{
      'mp3': ascii('ID3'),
      'm4a': [0, 0, 0, 0x20, ...ascii('ftypM4A ')],
      'ogg': ascii('OggS'),
      'wav': [...'RIFF'.codeUnits, 1, 2, 3, 4, ...'WAVE'.codeUnits],
      'aac': [0xFF, 0xF1, 0x50, 0x80],
    };
    cases.forEach((format, head) {
      test('accepts $format by magic bytes', () {
        expect(ReminderSoundValidator.formatOf(head), format);
      });
    });

    test('accepts mp3 frame sync without ID3', () {
      expect(ReminderSoundValidator.formatOf([0xFF, 0xFB, 0x90, 0x64]), 'mp3');
      expect(ReminderSoundValidator.formatOf([0xFF, 0xF3, 0x90, 0x64]), 'mp3');
    });

    test('rejects a pdf renamed to .mp3', () {
      expect(ReminderSoundValidator.formatOf(ascii('%PDF-1.7')), isNull);
    });

    test('rejects empty and truncated heads', () {
      expect(ReminderSoundValidator.formatOf([]), isNull);
      expect(ReminderSoundValidator.formatOf([0xFF]), isNull);
      expect(ReminderSoundValidator.formatOf('RIFF'.codeUnits), isNull);
    });
  });

  group('checkFile__AC4', () {
    final mp3 = ascii('ID3');

    test('10 MB exactly is accepted', () {
      expect(
          ReminderSoundValidator.checkFile(size: 10485760, head: mp3), isNull);
    });

    test('10 MB + 1 byte is too large', () {
      final error = ReminderSoundValidator.checkFile(size: 10485761, head: mp3);
      expect(error, ReminderSoundError.tooLarge);
      expect(error!.message, 'File quá lớn (tối đa 10 MB)');
    });

    test('unknown bytes are unsupported', () {
      final error =
          ReminderSoundValidator.checkFile(size: 1000, head: ascii('%PDF'));
      expect(error!.message, 'Định dạng không hỗ trợ');
    });

    test('empty file is unsupported', () {
      expect(ReminderSoundValidator.checkFile(size: 0, head: const []),
          ReminderSoundError.unsupportedFormat);
    });
  });

  group('checkDuration__AC4', () {
    test('1 s and 30 s boundaries are accepted', () {
      expect(ReminderSoundValidator.checkDuration(1000), isNull);
      expect(ReminderSoundValidator.checkDuration(30000), isNull);
      expect(ReminderSoundValidator.checkDuration(15000), isNull);
    });

    test('just outside the boundaries is rejected', () {
      for (final ms in [999, 900, 30001, 30100]) {
        final error = ReminderSoundValidator.checkDuration(ms);
        expect(error!.message, 'Âm thanh phải dài từ 1 đến 30 giây',
            reason: '$ms');
      }
    });

    test('undecodable file has its own message', () {
      expect(ReminderSoundValidator.checkDuration(null)!.message,
          'Không phát được file này');
    });
  });
}
