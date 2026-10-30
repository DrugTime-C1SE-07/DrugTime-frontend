import 'dart:async';

import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/state/consent_controller.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code_failure.dart';
import 'package:drugtime_mobile/features/family/domain/repositories/family_link_code_repository.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_link_code_controller.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/sources/camera_permission.dart';
import 'package:drugtime_mobile/features/family_link/data/sources/invite_link_sharer.dart';
import 'package:drugtime_mobile/features/family_link/domain/repositories/caregiver_repository.dart';
import 'package:drugtime_mobile/features/family_link/domain/repositories/family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/family_link_scope.dart';
import 'package:drugtime_mobile/features/family_link/presentation/state/invite_link_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testInviteHost = 'drug-time-frontend.vercel.app';

class FakeCameraPermission implements CameraPermission {
  FakeCameraPermission(this.status);

  CameraPermissionStatus status;
  int requests = 0;
  int openSettingsCalls = 0;

  /// Có giá trị thì `request()` chờ completer này (giả hộp thoại quyền đang mở).
  Completer<CameraPermissionStatus>? pending;

  /// Có giá trị thì `request()` ném lỗi này (giả lỗi nền tảng).
  Exception? error;

  @override
  Future<CameraPermissionStatus> request() async {
    requests++;
    if (error case final e?) throw e;
    if (pending case final p?) return p.future;
    return status;
  }

  @override
  Future<void> openSettings() async => openSettingsCalls++;
}

class FakeInviteLinkSharer implements InviteLinkSharer {
  final List<String> shared = [];

  @override
  Future<void> share(String text) async => shared.add(text);
}

/// Mã của người dùng (3.11). Mỗi lần gọi lấy một kết quả từ [results]; hết thì trả mã mẫu.
class FakeFamilyLinkCodeRepository implements FamilyLinkCodeRepository {
  FakeFamilyLinkCodeRepository([List<Object>? results]) : results = results ?? [];

  final List<Object> results;

  @override
  Future<FamilyLinkCode> fetch() async {
    if (results.isEmpty) {
      return const FamilyLinkCode(
          code: 'K7M2Q9XAR4', qrPayload: 'drugtime://link?code=K7M2Q9XAR4');
    }
    final result = results.removeAt(0);
    if (result is FamilyLinkCodeFailure) throw result;
    return result as FamilyLinkCode;
  }
}

/// Dựng [home] trong `MaterialApp` dùng router thật, bọc các scope mà luồng người thân cần:
/// `FamilyLinkScope`, scope mã của 3.11 và `ConsentScope`. Không truyền [caregivers] thì dùng
/// repository trong bộ nhớ rỗng (không có yêu cầu đang chờ, không có người giám sát).
Future<void> pumpFamilyLink(
  WidgetTester tester,
  Widget home, {
  required FamilyLinkRepository repository,
  CaregiverRepository? caregivers,
  CameraPermission? cameraPermission,
  InviteLinkSharer? sharer,
  FamilyLinkCodeRepository? codeRepository,
  Set<ConsentPurpose> consents = const {
    ConsentPurpose.healthData,
    ConsentPurpose.familySharing,
    ConsentPurpose.terms,
  },
}) async {
  tester.view.physicalSize = const Size(400, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final invites = InviteLinkController();
  final codes = FamilyLinkCodeController(codeRepository ?? FakeFamilyLinkCodeRepository());
  final consentController = ConsentController(InMemoryConsentRepository(granted: consents));
  await consentController.load();
  addTearDown(invites.dispose);
  addTearDown(codes.dispose);
  addTearDown(consentController.dispose);
  // Khóa mới mỗi lần: gọi lại trong cùng một test thì dựng cây mới, không giữ state cũ.
  await tester.pumpWidget(ConsentScope(
    key: UniqueKey(),
    controller: consentController,
    child: FamilyLinkCodeScope(
      controller: codes,
      child: FamilyLinkScope(
        repository: repository,
        caregivers: caregivers ?? InMemoryCaregiverRepository(),
        invites: invites,
        cameraPermission: cameraPermission ?? FakeCameraPermission(CameraPermissionStatus.granted),
        sharer: sharer ?? FakeInviteLinkSharer(),
        inviteLinkHost: testInviteHost,
        child: MaterialApp(home: home, onGenerateRoute: onGenerateRoute),
      ),
    ),
  ));
  await tester.pump();
}
