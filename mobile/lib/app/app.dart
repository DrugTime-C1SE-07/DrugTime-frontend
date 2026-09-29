import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/repositories/medication_repository.dart';
import '../features/medication/presentation/state/medication_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class DrugTimeApp extends StatefulWidget {
  const DrugTimeApp({super.key, this.medicationRepository});

  /// Cho phép test/bản build khác thay nguồn dữ liệu.
  final MedicationRepository? medicationRepository;

  @override
  State<DrugTimeApp> createState() => _DrugTimeAppState();
}

class _DrugTimeAppState extends State<DrugTimeApp> {
  late final MedicationController _medications = MedicationController(
    widget.medicationRepository ?? InMemoryMedicationRepository(),
  )..load();

  @override
  void dispose() {
    _medications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Scope đặt trên MaterialApp để mọi route (kể cả bottom sheet) đều truy cập được.
    return MedicationScope(
      controller: _medications,
      child: MaterialApp(
        title: 'DrugTime',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('vi'),
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        initialRoute: AppRoutes.home,
        onGenerateRoute: onGenerateRoute,
      ),
    );
  }
}
