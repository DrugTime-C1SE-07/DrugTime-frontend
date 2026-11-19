import '../features/auth/domain/entities/auth_session.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/state/auth_controller.dart';
import '../features/consent/data/repositories/in_memory_consent_repository.dart';
import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/profile/data/repositories/profile_preview_repository.dart';
import '../features/family_link/data/repositories/in_memory_family_link_repository.dart';
import '../features/family/domain/entities/family_link_code.dart';
import '../features/family/domain/repositories/family_link_code_repository.dart';
import '../features/adherence_history/data/models/adherence_demo_fixtures.dart';
import '../features/adherence_history/data/repositories/demo_adherence_history_repository.dart';
import '../features/adherence_history/domain/entities/adherence_demo_preset.dart';

/// Owns disposable, memory-only dependencies for one app preview epoch.
class AppPreviewSession {
  AppPreviewSession(
      {DateTime? now,
      bool authenticated = true,
      AdherenceDemoPreset preset = AdherenceDemoPreset.mixed,
      void Function()? onLogout}) {
    final vn = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
    clock = DateTime.utc(vn.year, vn.month, vn.day, 7);
    history = DemoAdherenceHistoryRepository(preset, clock: clock);
    auth = AuthController(_PreviewAuthRepository(authenticated, onLogout));
  }
  late final DateTime clock;
  late final DemoAdherenceHistoryRepository history;
  late final AuthController auth;
  final medications = InMemoryMedicationRepository();
  final consents = InMemoryConsentRepository();
  final profile = ProfilePreviewRepository();
  final family = InMemoryFamilyLinkRepository();
  final FamilyLinkCodeRepository codes = _PreviewFamilyCodeRepository();
  void dispose() {
    history.close();
    auth.dispose();
  }
}

class _PreviewFamilyCodeRepository implements FamilyLinkCodeRepository {
  @override
  Future<FamilyLinkCode> fetch() async => const FamilyLinkCode(
      code: 'MẪU', qrPayload: 'drugtime-preview:sample-only');
}

class _PreviewAuthRepository implements AuthRepository {
  _PreviewAuthRepository(bool authenticated, this.onLogout)
      : _session = authenticated ? _newSession() : null;
  final void Function()? onLogout;
  AuthSession? _session;
  static AuthSession _newSession() => AuthSession(
      userId: AdherenceDemoFixtures.patientId,
      accessToken: 'preview-only',
      profileComplete: true,
      expiresAt: DateTime.now().add(const Duration(days: 30)));
  @override
  Future<AuthSession?> getCurrentSession() async => _session;
  @override
  Future<void> requestOtp({String? phone, String? email}) async {}
  @override
  Future<AuthSession> verifyOtp(
          {String? phone, String? email, required String token}) async =>
      _session = _newSession();
  @override
  Future<AuthSession> completeProfile(
          {required String fullName,
          required DateTime dateOfBirth,
          required String gender}) async =>
      _session ??= _newSession();
  @override
  Future<void> signOut() async {
    _session = null;
    onLogout?.call();
  }
}
