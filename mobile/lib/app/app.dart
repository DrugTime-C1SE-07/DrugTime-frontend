import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/data/repositories/in_memory_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/state/auth_controller.dart';
import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/repositories/medication_repository.dart';
import '../features/medication/presentation/state/medication_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class DrugTimeApp extends StatefulWidget {
  const DrugTimeApp({
    super.key,
    this.medicationRepository,
    this.authRepository,
    this.initialRoute = AppRoutes.home,
  });

  /// Cho phép test/bản build khác thay nguồn dữ liệu thuốc.
  final MedicationRepository? medicationRepository;

  /// Cho phép test/bản build khác thay nguồn dữ liệu xác thực.
  final AuthRepository? authRepository;

  /// Route ban đầu khi mở ứng dụng.
  final String initialRoute;

  @override
  State<DrugTimeApp> createState() => _DrugTimeAppState();
}

class _DrugTimeAppState extends State<DrugTimeApp> {
  late final MedicationController _medications = MedicationController(
    widget.medicationRepository ?? InMemoryMedicationRepository(),
  )..load();

  late final AuthController _auth = AuthController(
    widget.authRepository ?? InMemoryAuthRepository(),
  )..initSession();

  @override
  void dispose() {
    _medications.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scopes đặt trên MaterialApp để mọi route (kể cả modal bottom sheet) đều truy cập được.
    return AuthScope(
      controller: _auth,
      child: MedicationScope(
        controller: _medications,
        child: MaterialApp(
          title: 'DrugTime',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          locale: const Locale('vi'),
          supportedLocales: const [Locale('vi'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          initialRoute: widget.initialRoute,
          onGenerateRoute: onGenerateRoute,
        ),
      ),
    );
  }
}
