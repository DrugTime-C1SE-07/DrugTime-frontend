import 'package:flutter/material.dart';

import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/entities/medication.dart';
import '../features/medication/presentation/screens/add_medication_screen.dart';
import '../features/medication/presentation/screens/edit_medication_screen.dart';
import '../features/medication/presentation/screens/medication_detail_screen.dart';
import 'app_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const addMedication = '/medications/add';
  static const medicationDetail = '/medications/detail';
  static const editMedication = '/medications/edit';
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
    AppRoutes.medicationDetail => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) {
          final medication = settings.arguments as Medication?;
          return MedicationDetailScreen(
            medication: medication ?? sampleMedications.first,
          );
        },
      ),
    AppRoutes.editMedication => MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (_) {
          final medication = settings.arguments as Medication?;
          return EditMedicationScreen(
            medication: medication ?? sampleMedications[1],
          );
        },
      ),
    _ => null,
  };
}
