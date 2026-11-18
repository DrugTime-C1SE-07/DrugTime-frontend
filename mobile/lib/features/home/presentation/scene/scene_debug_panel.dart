import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'home_pet_signals.dart';

/// Giá trị giả lập cho bảng xem trước (chỉ bản debug): tua giờ và bật tắt tín hiệu.
class SceneDebugOverrides extends ChangeNotifier {
  /// Thời điểm giả lập; `null` = giờ thật.
  DateTime? now;
  bool doseWindow = false,
      missed = false,
      allDone = false,
      pending = false,
      remaining = false,
      failed = false,
      empty = false;
  int? streak;
  int confirmed = 0, failedSeq = 0;

  bool get active =>
      now != null ||
      doseWindow ||
      missed ||
      allDone ||
      pending ||
      remaining ||
      failed ||
      empty ||
      streak != null ||
      confirmed > 0 ||
      failedSeq > 0;

  /// Khi đang giả lập, chỉ dùng các tín hiệu bật trong bảng (bỏ tín hiệu thật của dữ liệu),
  /// để xem được từng trạng thái riêng, ví dụ pet ngủ dù dữ liệu thật có liều đến giờ.
  HomePetSignals apply(HomePetSignals s) {
    if (!active) return s;
    return HomePetSignals(
      ictMinutes: now == null ? s.ictMinutes : HomePetSignals.minutesOf(now!),
      failed: failed,
      empty: empty,
      inDoseWindow: doseWindow,
      missedToday: missed,
      allDone: allDone,
      pending: pending,
      remaining: remaining,
      streak: streak ?? s.streak,
      confirmedSeq: s.confirmedSeq + confirmed,
      confirmFailedSeq: s.confirmFailedSeq + failedSeq,
    );
  }

  void changed() => notifyListeners();

  void reset() {
    now = null;
    doseWindow =
        missed = allDone = pending = remaining = failed = empty = false;
    streak = null;
    notifyListeners();
  }
}

/// Mở bảng tua giờ và giả lập trạng thái. Chỉ gọi trong bản debug.
Future<void> showSceneDebugPanel(BuildContext context, SceneDebugOverrides o) {
  assert(kDebugMode);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => ListenableBuilder(
      listenable: o,
      builder: (context, _) {
        final base = o.now ?? DateTime.now();
        final ict = base.toUtc().add(const Duration(hours: 7));
        final hour = ict.hour + ict.minute / 60;
        final day = DateTime.utc(ict.year, ict.month, ict.day);
        final doy = day.difference(DateTime.utc(ict.year)).inDays.toDouble();
        DateTime at(double doyValue, double h) => DateTime.utc(ict.year)
            .add(Duration(days: doyValue.round(), minutes: (h * 60).round()))
            .subtract(const Duration(hours: 7));
        Widget flag(String label, bool v, void Function(bool) set) =>
            FilterChip(
                label: Text(label),
                selected: v,
                onSelected: (x) {
                  set(x);
                  o.changed();
                });
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text('Xem trước banner (debug)',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(
                  'Giờ VN: ${ict.hour.toString().padLeft(2, '0')}:${ict.minute.toString().padLeft(2, '0')} · ngày ${ict.day}/${ict.month}'),
              Slider(
                value: hour.clamp(0, 23.99),
                max: 23.99,
                divisions: 96,
                label: '${hour.floor()}h',
                onChanged: (h) {
                  o.now = at(doy, h);
                  o.changed();
                },
              ),
              Slider(
                value: doy.clamp(0, 364),
                max: 364,
                divisions: 52,
                label: 'ngày ${doy.round() + 1}',
                onChanged: (d) {
                  o.now = at(d, hour);
                  o.changed();
                },
              ),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final (label, h) in [
                  ('06:00', 6.0),
                  ('12:00', 12.0),
                  ('17:45', 17.75),
                  ('21:40', 21.67),
                  ('22:30', 22.5),
                ])
                  ActionChip(
                      label: Text(label),
                      onPressed: () {
                        o.now = at(doy, h);
                        o.changed();
                      }),
              ]),
              const Divider(),
              Wrap(spacing: 8, runSpacing: 4, children: [
                flag(
                    'Liều trong cửa sổ', o.doseWindow, (v) => o.doseWindow = v),
                flag('Có liều bỏ lỡ', o.missed, (v) => o.missed = v),
                flag('Xong mọi liều', o.allDone, (v) => o.allDone = v),
                flag('Chờ đồng bộ', o.pending, (v) => o.pending = v),
                flag('Còn liều', o.remaining, (v) => o.remaining = v),
                flag('Lỗi tải', o.failed, (v) => o.failed = v),
                flag('Chưa có thuốc', o.empty, (v) => o.empty = v),
                ActionChip(
                    label: const Text('Ăn mừng'),
                    onPressed: () {
                      o.confirmed++;
                      o.changed();
                    }),
                ActionChip(
                    label: const Text('Ghi nhận lỗi'),
                    onPressed: () {
                      o.failedSeq++;
                      o.changed();
                    }),
                ActionChip(
                    label: const Text('Mốc 7 ngày'),
                    onPressed: () {
                      o.streak = 7;
                      o.changed();
                    }),
              ]),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: o.reset, child: const Text('Về giờ thật')),
            ],
          ),
        );
      },
    ),
  );
}
