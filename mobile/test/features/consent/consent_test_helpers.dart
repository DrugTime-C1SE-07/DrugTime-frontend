import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent_failure.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication.dart';
import 'package:drugtime_mobile/features/medication/domain/entities/medication_failure.dart';
import 'package:drugtime_mobile/features/medication/domain/repositories/medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Consent trong bộ nhớ, ghi lại mọi lời gọi; có thể ép lỗi cho lần gọi kế tiếp.
///
/// Mặc định đã đồng ý `terms` (bản hiện hành) để test của luồng `health_data` không phải đi qua
/// màn điều khoản. Test luồng điều khoản đặt [termsAccepted] = false, hoặc truyền phiên bản cũ
/// qua `grantedVersions`.
class RecordingConsentRepository extends InMemoryConsentRepository {
  RecordingConsentRepository({
    Set<ConsentPurpose> granted = const {},
    bool termsAccepted = true,
    super.grantedVersions,
  }) : super(granted: {...granted, if (termsAccepted) ConsentPurpose.terms});

  final List<String> calls = [];

  /// Lỗi ném ở lần gọi kế tiếp (rồi tự xóa).
  ConsentFailure? failNext;

  /// Lỗi ném ở mọi lần fetchAll.
  ConsentFailure? failFetch;

  /// Ném lỗi ở lần ghi (grant/withdraw) có thứ tự này, đếm từ 1.
  int? failOnWrite;
  ConsentFailure failOnWriteWith = const ConsentFailure(ConsentFailureKind.network);

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  void _maybeFailWrite() {
    _maybeFail();
    if (writes.length == failOnWrite) {
      failOnWrite = null;
      throw failOnWriteWith;
    }
  }

  @override
  Future<List<ConsentState>> fetchAll() async {
    calls.add('fetchAll');
    if (failFetch case final failure?) throw failure;
    _maybeFail();
    return super.fetchAll();
  }

  @override
  Future<ConsentState> grant(ConsentPurpose purpose) async {
    calls.add('grant:${purpose.apiValue}');
    _maybeFailWrite();
    return super.grant(purpose);
  }

  @override
  Future<ConsentState> withdraw(ConsentPurpose purpose) async {
    calls.add('withdraw:${purpose.apiValue}');
    _maybeFailWrite();
    return super.withdraw(purpose);
  }

  List<String> get writes => calls.where((c) => c != 'fetchAll').toList();
}

/// Thuốc trong bộ nhớ, nhưng trả 403 `consent_revoked` khi người dùng chưa có `health_data`
/// (đọc từ [consents]), giống server.
class ConsentAwareMedicationRepository extends InMemoryMedicationRepository
    implements MedicationRepository {
  ConsentAwareMedicationRepository(this.consents);

  final InMemoryConsentRepository consents;
  int fetchCount = 0;

  Future<void> _check() async {
    final states = await consents.fetchAll();
    if (!states.firstWhere((s) => s.purpose == ConsentPurpose.healthData).granted) {
      throw const MedicationFailure(MedicationFailureKind.consentRevoked, 'consent_revoked');
    }
  }

  @override
  Future<List<Medication>> fetchAll() async {
    fetchCount++;
    await _check();
    return super.fetchAll();
  }

  @override
  Future<Medication> add(Medication draft, {required String clientUuid}) async {
    await _check();
    return super.add(draft, clientUuid: clientUuid);
  }
}

AuthController signedInAuth() => AuthController(
      InMemoryAuthRepository(
        simulatedDelay: Duration.zero,
        initialSession: AuthSession(
          userId: 'test-user',
          accessToken: 'test-token',
          expiresAt: DateTime.now().add(const Duration(days: 10)),
          profileComplete: true,
        ),
      ),
    );

/// Dựng app đã đăng nhập, hồ sơ đủ, với consent và thuốc cho trước.
Future<void> pumpConsentApp(
  WidgetTester tester, {
  required InMemoryConsentRepository consents,
  MedicationRepository? medications,
  String? initialRoute,
  AuthController? auth,
}) async {
  // Cao hơn màn thật để ListView dựng đủ ba thẻ và nút, không phải cuộn trong test.
  tester.view.physicalSize = const Size(375, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(DrugTimeApp(
    authController: auth ?? signedInAuth(),
    consentRepository: consents,
    medicationRepository: medications ?? InMemoryMedicationRepository(),
    initialRoute: initialRoute,
  ));
  await tester.pumpAndSettle();
}

Finder consentSwitch(ConsentPurpose purpose) => find.byKey(Key('consent-switch-${purpose.apiValue}'));

bool switchValue(WidgetTester tester, ConsentPurpose purpose) =>
    tester.widget<Switch>(consentSwitch(purpose)).value;
