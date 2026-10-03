import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/sync/sync_engine.dart';
import '../features/auth/presentation/state/auth_controller.dart';
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
    this.doseOutboxSyncEngine,
    this.initialRoute,
  });

  /// Trạng thái đăng nhập; app chạy thật dựng với RemoteAuthRepository (xem main.dart).
  final AuthController authController;

  /// Cho phép test/bản build khác thay nguồn dữ liệu thuốc.
  final MedicationRepository? medicationRepository;
  final DoseOutboxSyncEngine? doseOutboxSyncEngine;

  /// Ép route đầu (test, dev catalog). Không truyền thì chọn theo phiên đăng nhập.
  final String? initialRoute;

  @override
  State<DrugTimeApp> createState() => _DrugTimeAppState();
}

class _DrugTimeAppState extends State<DrugTimeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Chỉ tải khi đã có phiên: gọi API trước khi đăng nhập sẽ nhận 401 và đá người dùng về
  /// màn Đăng nhập.
  late final MedicationController _medications = MedicationController(
    widget.medicationRepository ?? InMemoryMedicationRepository(),
  );

  AuthController get _auth => widget.authController;

  bool _sessionLoaded = false;
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    final syncEngine = widget.doseOutboxSyncEngine;
    if (syncEngine != null) {
      unawaited(syncEngine.start());
    }
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

  /// Mất phiên (đăng xuất hoặc API trả 401) thì đưa người dùng về màn Đăng nhập.
  void _onAuthChanged() {
    if (!_sessionLoaded) return;
    final authenticated = _auth.isAuthenticated;
    if (_wasAuthenticated && !authenticated) {
      _medications.clear();
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
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
    if (syncEngine != null) {
      unawaited(syncEngine.dispose());
    }
    _medications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scopes đặt trên MaterialApp để mọi route (kể cả modal bottom sheet) đều truy cập được.
    return AuthScope(
      controller: _auth,
      child: MedicationScope(
        controller: _medications,
        child: _sessionLoaded ? _buildApp() : const _SessionLoadingApp(),
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
      // Chỉ dựng đúng một route đầu; mặc định Flutter tách '/login' thành ['/', '/login'],
      // khiến nút Back ở màn Đăng nhập quay về Trang chủ khi chưa đăng nhập.
      onGenerateInitialRoutes: (name) => [onGenerateRoute(RouteSettings(name: name))!],
    );
  }
}

/// Màn chờ trong lúc đọc phiên đã lưu (MaterialApp riêng, không dùng navigatorKey của app).
class _SessionLoadingApp extends StatelessWidget {
  const _SessionLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _SessionLoadingScreen(),
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    // Cùng nền với màn khởi động của hệ điều hành và cùng ảnh mascot, để chuyển cảnh không giật.
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
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
