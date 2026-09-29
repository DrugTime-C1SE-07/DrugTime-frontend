import 'package:flutter/material.dart';

import '../features/medication/domain/entities/medication.dart';
import '../features/medication/presentation/screens/add_medication_screen.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const addMedication = '/medications/add';
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  return switch (settings.name) {
    AppRoutes.home => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AppShell(),
      ),
    AppRoutes.addMedication => MaterialPageRoute<Medication>(
        settings: settings,
        builder: (_) => const AddMedicationScreen(),
      ),
    _ => null,
  };
}
