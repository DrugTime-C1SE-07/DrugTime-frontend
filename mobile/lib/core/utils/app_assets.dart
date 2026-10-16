/// Đường dẫn ảnh trong assets/ — gom một chỗ để đổi tên file chỉ cần sửa tại đây.
/// Dùng: `Image.asset(AppAssets.mascotHappy)`.
abstract final class AppAssets {
  static const profileAvatars = [
    'assets/images/boy.jpg',
    'assets/images/girl.jpg',
    'assets/images/old-man.jpg',
    'assets/images/old-woman.jpg',
    'assets/images/young-girl.jpg',
    'assets/images/young-man.jpg',
  ];
  static const _icons = 'assets/icons';

  static const logo = '$_icons/logo.png';

  static const mascotAngry = '$_icons/mascot-angry.png';
  static const mascotCooking = '$_icons/mascot-cooking.png';
  static const mascotHappy = '$_icons/mascot-happy.png';
  static const mascotHello = '$_icons/mascot-hello.png';
  static const mascotInteraction = '$_icons/mascot-interaction.png';
  static const mascotProtect = '$_icons/mascot-protect.png';
  static const mascotRunning = '$_icons/mascot-running.png';
  static const mascotThinking = '$_icons/mascot-thinking.png';

  static const all = [
    logo,
    mascotAngry,
    mascotCooking,
    mascotHappy,
    mascotHello,
    mascotInteraction,
    mascotProtect,
    mascotRunning,
    mascotThinking,
  ];
}
