import 'package:flutter/widgets.dart';

import '../../../../core/config/app_config.dart';
import '../../data/sources/camera_permission.dart';
import '../../data/sources/invite_link_sharer.dart';
import '../../domain/repositories/caregiver_repository.dart';
import '../../domain/repositories/family_link_repository.dart';
import 'incoming_requests_controller.dart';
import 'invite_link_controller.dart';

/// Phụ thuộc của luồng theo dõi người thân, đặt trên `MaterialApp` để mọi route dùng được.
class FamilyLinkScope extends InheritedWidget {
  const FamilyLinkScope({
    super.key,
    required this.repository,
    required this.caregivers,
    required this.invites,
    this.incomingRequests,
    this.cameraPermission = const SystemCameraPermission(),
    this.sharer = const SystemInviteLinkSharer(),
    this.inviteLinkHost = AppConfig.inviteLinkHost,
    required super.child,
  });

  final FamilyLinkRepository repository;

  /// Phía patient: duyệt yêu cầu theo dõi và quản lý người giám sát.
  final CaregiverRepository caregivers;
  final InviteLinkController invites;
  final IncomingRequestsController? incomingRequests;
  final CameraPermission cameraPermission;
  final InviteLinkSharer sharer;
  final String inviteLinkHost;

  /// Không đăng ký rebuild — các màn chỉ đọc phụ thuộc, không đọc trạng thái.
  static FamilyLinkScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FamilyLinkScope>();
    assert(scope != null, 'Không tìm thấy FamilyLinkScope phía trên widget này');
    return scope!;
  }

  static FamilyLinkScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FamilyLinkScope>();

  @override
  bool updateShouldNotify(FamilyLinkScope oldWidget) =>
      repository != oldWidget.repository ||
      caregivers != oldWidget.caregivers ||
      invites != oldWidget.invites ||
      incomingRequests != oldWidget.incomingRequests ||
      cameraPermission != oldWidget.cameraPermission ||
      sharer != oldWidget.sharer ||
      inviteLinkHost != oldWidget.inviteLinkHost;
}
