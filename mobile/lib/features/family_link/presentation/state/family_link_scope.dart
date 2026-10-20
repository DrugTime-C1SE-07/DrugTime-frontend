import 'package:flutter/widgets.dart';

import '../../../../core/config/app_config.dart';
import '../../data/sources/camera_permission.dart';
import '../../data/sources/invite_link_sharer.dart';
import '../../domain/repositories/family_link_repository.dart';
import 'invite_link_controller.dart';

/// Phụ thuộc của luồng theo dõi người thân, đặt trên `MaterialApp` để mọi route dùng được.
class FamilyLinkScope extends InheritedWidget {
  const FamilyLinkScope({
    super.key,
    required this.repository,
    required this.invites,
    this.cameraPermission = const SystemCameraPermission(),
    this.sharer = const SystemInviteLinkSharer(),
    this.inviteLinkHost = AppConfig.inviteLinkHost,
    required super.child,
  });

  final FamilyLinkRepository repository;
  final InviteLinkController invites;
  final CameraPermission cameraPermission;
  final InviteLinkSharer sharer;
  final String inviteLinkHost;

  /// Không đăng ký rebuild — các màn chỉ đọc phụ thuộc, không đọc trạng thái.
  static FamilyLinkScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FamilyLinkScope>();
    assert(scope != null, 'Không tìm thấy FamilyLinkScope phía trên widget này');
    return scope!;
  }

  @override
  bool updateShouldNotify(FamilyLinkScope oldWidget) =>
      repository != oldWidget.repository ||
      invites != oldWidget.invites ||
      cameraPermission != oldWidget.cameraPermission ||
      sharer != oldWidget.sharer ||
      inviteLinkHost != oldWidget.inviteLinkHost;
}
