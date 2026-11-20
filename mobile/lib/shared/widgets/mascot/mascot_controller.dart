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

  /// Đầu bếp đang "nấu": lắc bát, nhún theo nhịp, rau trong bát nảy lên.
  cooking,

  /// Ôm bụng dịu dàng, một trái tim nhỏ bay lên (chọn tình trạng mang thai / cho con bú).
  cradle,

  /// Dang hai tay ôm bạn bên cạnh, má ửng, tim nhỏ; tự quay về trạng thái trước.
  hug,

  /// Được xoa đầu: nhắm mắt cười, má ửng đậm, tim bay lên; tự quay về trạng thái trước.
  blissful,
  farewell,
  thumbsUp,
}

/// Trang phục của linh vật. [chef]: mũ đầu bếp + bát salad ở tay phải.
/// [medic]: mũ y tá có chữ thập + ống nghe, dùng ở các màn hồ sơ sức khỏe.
/// [gardenHat]: mũ cói làm vườn có dải ruy băng. [scarf]: khăn quàng cổ có tua.
enum MascotOutfit { plain, chef, medic, gardenHat, scarf }

/// Bảng màu phần thân dưới của viên thuốc. [blue] là màu gốc của DrugTime.
enum MascotPalette {
  blue(Color(0xFF1B9AFC), Color(0xFF0A7FEF), Color(0xFFB4E4FC),
      Color(0xFF1D5BB0)),
  peach(Color(0xFFFF9A62), Color(0xFFF2763A), Color(0xFFFFD9BF),
      Color(0xFFB4502A));

  const MascotPalette(this.base, this.deep, this.light, this.line);

  /// Màu chính và màu đậm của gradient thân dưới.
  final Color base, deep;

  /// Vệt sáng trên thân dưới.
  final Color light;

  /// Viền thân.
  final Color line;
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
