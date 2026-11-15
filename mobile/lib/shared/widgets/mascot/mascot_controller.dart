import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Trạng thái của linh vật (tương đương các state trong một state machine hoạt họa).
enum MascotMood {
  /// Chưa xuất hiện.
  hidden,

  /// Vào màn: bám mép form → ngó lên → đu lên → nhảy lên mây, rồi chuyển sang [wave].
  climb,
  idle,
  wave,
  celebrate,
  protect,
  concerned,
  sleepy,
  thinking,
  cover,
  poke,
}

/// Màn hình điều khiển linh vật qua controller: đổi trạng thái, hướng nhìn, hé mắt.
class MascotController extends ChangeNotifier {
  MascotMood _mood = MascotMood.hidden;
  int _seq = 0;
  Offset? _gaze;
  int _gazeStamp = 0;
  bool _peek = false;

  /// Toạ độ y (đơn vị khung linh vật 300×300) của mép trên form đăng nhập — chỗ để bám.
  double ledge = 360;

  MascotMood get mood => _mood;

  /// Tăng mỗi lần [play], kể cả khi phát lại cùng một trạng thái.
  int get seq => _seq;

  /// Hướng nhìn mong muốn, mỗi trục trong khoảng -1..1 (x: trái→phải, y: trên→dưới).
  Offset? get gaze => _gaze;

  /// Tăng mỗi lần [lookAt], để linh vật biết người dùng vừa thao tác.
  int get gazeStamp => _gazeStamp;

  bool get peek => _peek;

  void play(MascotMood mood) {
    _mood = mood;
    _seq++;
    notifyListeners();
  }

  void lookAt(Offset gaze) {
    _gaze = Offset(gaze.dx.clamp(-1.0, 1.0), gaze.dy.clamp(-1.0, 1.0));
    _gazeStamp++;
    notifyListeners();
  }

  void clearLook() {
    if (_gaze == null) return;
    _gaze = null;
    notifyListeners();
  }

  void setPeek(bool peek) {
    if (_peek == peek) return;
    _peek = peek;
    notifyListeners();
  }
}
