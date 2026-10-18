import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/sync/sync_engine.dart';
import '../features/auth/presentation/state/auth_controller.dart';
import '../features/consent/data/repositories/in_memory_consent_repository.dart';
import '../features/consent/domain/repositories/consent_repository.dart';
import '../features/consent/presentation/state/consent_controller.dart';
import '../features/family/domain/entities/family_link_code.dart';
import '../features/family/domain/entities/family_link_code_failure.dart';
import '../features/family/domain/repositories/family_link_code_repository.dart';
import '../features/family/presentation/state/family_link_code_controller.dart';
import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/repositories/medication_repository.dart';
import '../features/medication/presentation/state/medication_controller.dart';
import 'router.dart';
import '../core/utils/app_assets.dart';
import 'theme/app_theme.dart';

class DrugTimeApp extends StatefulWidget {
  const DrugTimeApp({
    super.key,
    required this.authController,
    this.medicationRepository,
    this.consentRepository,
    this.familyLinkCodeRepository,
    this.doseOutboxSyncEngine,
    this.initialRoute,
  });

  /// Trạng thái đăng nhập; app chạy thật dựng với RemoteAuthRepository (xem main.dart).
  final AuthController authController;

  /// Cho phép test/bản build khác thay nguồn dữ liệu thuốc.
  final MedicationRepository? medicationRepository;

  /// Không truyền thì dùng consent trong bộ nhớ đã đồng ý `health_data` (vào thẳng Trang chủ).
  final ConsentRepository? consentRepository;

  /// Cho phép test thay nguồn lấy mã liên kết; bản thật dùng Backend API.
  final FamilyLinkCodeRepository? familyLinkCodeRepository;
  final DoseOutboxSyncEngine? doseOutboxSyncEngine;

  /// Ép route đầu (test, dev catalog). Không truyền thì chọn theo phiên đăng nhập.
  final String? initialRoute;

  @override
  State<DrugTimeApp> createState() => _DrugTimeAppState();
}

class _DrugTimeAppState extends State<DrugTimeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  late final MedicationController _medications = MedicationController(
    widget.medicationRepository ?? InMemoryMedicationRepository(),
  );

  late final ConsentController _consents = ConsentController(
    widget.consentRepository ?? InMemoryConsentRepository(),
  );

  late final FamilyLinkCodeController _familyLinkCode =
      FamilyLinkCodeController(
    widget.familyLinkCodeRepository ?? _UnavailableFamilyLinkCodeRepository(),
  );

  AuthController get _auth => widget.authController;

  bool _sessionLoaded = false;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    final syncEngine = widget.doseOutboxSyncEngine;
    if (syncEngine != null) unawaited(syncEngine.start());
    _auth.addListener(_onAuthChanged);
    unawaited(_loadSession());
  }

  Future<void> _loadSession() async {
    await _auth.initSession();
    if (!mounted) return;
    setState(() {
      _sessionLoaded = true;
      _wasAuthenticated = _auth.isAuthenticated;
    });
    if (_auth.isAuthenticated) unawaited(_medications.load());
  }

  void _onAuthChanged() {
    if (!_sessionLoaded) return;
    final authenticated = _auth.isAuthenticated;
    if (_wasAuthenticated && !authenticated) {
      _medications.clear();
      _consents.clear();
      _familyLinkCode.clear();
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    } else if (!_wasAuthenticated && authenticated) {
      unawaited(_medications.load());
    }
    _wasAuthenticated = authenticated;
  }

  String get _startRoute {
    if (widget.initialRoute case final route?) return route;
    if (!_auth.isAuthenticated) return AppRoutes.login;
    return _auth.needsProfile ? AppRoutes.completeProfile : AppRoutes.home;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    final syncEngine = widget.doseOutboxSyncEngine;
    if (syncEngine != null) unawaited(syncEngine.dispose());
    _medications.dispose();
    _consents.dispose();
    _familyLinkCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: MedicationScope(
        controller: _medications,
        child: ConsentScope(
          controller: _consents,
          child: FamilyLinkCodeScope(
            controller: _familyLinkCode,
            child: _sessionLoaded ? _buildApp() : const _SessionLoadingApp(),
          ),
        ),
      ),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'DrugTime',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: _startRoute,
      onGenerateRoute: onGenerateRoute,
      onGenerateInitialRoutes: (name) =>
          [onGenerateRoute(RouteSettings(name: name))!],
    );
  }
}

class _SessionLoadingApp extends StatelessWidget {
  const _SessionLoadingApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _SessionLoadingScreen(),
      );
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              AppAssets.mascotHello,
              width: (width * 0.7).clamp(0.0, 280.0),
              cacheWidth: 840,
              fit: BoxFit.contain,
              semanticLabel: 'DrugTime',
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}

class _UnavailableFamilyLinkCodeRepository implements FamilyLinkCodeRepository {
  @override
  Future<FamilyLinkCode> fetch() => Future.error(
        const FamilyLinkCodeFailure(FamilyLinkCodeFailureKind.unavailable),
      );
}
