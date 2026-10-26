import 'package:flutter/material.dart';

import '../features/consent/presentation/screens/consent_screen.dart';
import '../features/consent/presentation/screens/legal_document_screen.dart';
import '../features/consent/presentation/screens/privacy_settings_screen.dart';
import '../features/consent/presentation/widgets/consent_gate.dart';
import '../features/consent/presentation/widgets/legal_texts.dart';
import '../features/family/presentation/screens/family_link_code_screen.dart';
import '../features/family/presentation/screens/family_alert_inbox_screen.dart';
import '../features/family/presentation/screens/family_alert_detail_screen.dart';
import '../features/auth/presentation/state/auth_controller.dart';
import '../features/family/domain/entities/family_alert.dart';
import '../features/family_link/presentation/screens/caregivers_screen.dart';
import '../features/family_link/presentation/screens/enter_link_code_screen.dart';
import '../features/family_link/presentation/screens/link_consent_confirmation_screen.dart';
import '../features/family_link/presentation/screens/link_request_result_screen.dart';
import '../features/family_link/presentation/screens/scan_link_qr_screen.dart';
import '../features/family_link/presentation/screens/share_invite_link_screen.dart';
import '../features/family_link/presentation/state/link_request_controller.dart';
import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/entities/medication.dart';
import '../features/medication/presentation/screens/edit_medication_screen.dart';
import '../features/medication/presentation/screens/medication_detail_screen.dart';
import '../features/medication/presentation/screens/add_medication_screen.dart';
import '../features/reminder/domain/entities/dose_reminder.dart';
import '../features/reminder/presentation/screens/dose_reminder_screen.dart';
import '../features/reminder/presentation/widgets/lockscreen_privacy_gate.dart';
import '../features/auth/presentation/screens/complete_profile_screen.dart';
import '../features/auth/presentation/screens/email_otp_screen.dart';
import '../features/auth/presentation/screens/login_mobile_screen.dart';
import '../features/auth/presentation/screens/phone_otp_screen.dart';
import 'app_shell.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/personal_profile_screen.dart';
import '../features/profile/presentation/screens/medical_profile_screen.dart';
import 'theme/app_theme.dart';

abstract final class AppRoutes {
  static const familyAlerts = '/family/alerts';
  static const familyAlertDetail = '/family/alerts/detail';
  static const home = '/';
  static const addMedication = '/medications/add';
  static const medicationDetail = '/medications/detail';
  static const editMedication = '/medications/edit';
  static const login = '/login';
  static const otpPhone = '/login/otp/phone';
  static const otpEmail = '/login/otp/email';
  static const completeProfile = '/onboarding/profile';
  static const consent = '/onboarding/consent';
  static const privacySettings = '/settings/privacy';
  static const termsOfService = '/legal/terms';
  static const privacyPolicy = '/legal/privacy';
  static const doseReminder = '/reminders/dose';
  static const profile = '/profile';
  static const personalProfile = '/profile/personal';
  static const medicalProfile = '/profile/medical';
  static const caregivers = '/profile/caregivers';
  static const familyMyCode = '/family/my-code';
  static const familyScanCode = '/family/follow/scan';
  static const familyEnterCode = '/family/follow/enter';
  static const familyLinkResult = '/family/follow/result';
  static const familyShareLink = '/family/share-link';
  static const linkConsentConfirmation = '/family/requests/confirm';
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  return switch (settings.name) {
    // Kiểm auth/consent cả khi đi vào từ push hoặc điều hướng trực tiếp tới route.
    AppRoutes.familyAlerts => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => AuthScope.of(context).isAuthenticated
            ? const ConsentGate(child: FamilyAlertInboxScreen())
            : const LoginMobileScreen()),
    AppRoutes.familyAlertDetail => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) {
          final id = settings.arguments;
          if (!AuthScope.of(context).isAuthenticated) {
            return const LoginMobileScreen();
          }
          if (id is! int || familyNotificationId('$id') == null) {
            return const Scaffold(
                body: Center(child: Text('Cảnh báo không còn khả dụng')));
          }
          return ConsentGate(child: FamilyAlertDetailScreen(id: id));
        }),
    AppRoutes.profile => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: ProfileScreen())),
    AppRoutes.personalProfile => MaterialPageRoute<void>(
        settings: settings, builder: (_) => const PersonalProfileScreen()),
    AppRoutes.medicalProfile => MaterialPageRoute<void>(
        settings: settings, builder: (_) => const MedicalProfileScreen()),
    AppRoutes.caregivers => MaterialPageRoute<CaregiversScreenResult>(
        settings: settings, builder: (_) => const CaregiversScreen()),
    // Mọi đường vào Trang chủ đi qua cổng consent (chưa có health_data thì hiện màn đồng ý).
    AppRoutes.home => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const ConsentGate(child: AppShell()),
      ),
    AppRoutes.consent => MaterialPageRoute<bool>(
        settings: settings,
        builder: (_) => const ConsentScreen(),
      ),
    AppRoutes.privacySettings => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const PrivacySettingsScreen(),
      ),
    AppRoutes.termsOfService => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const LegalDocumentScreen(document: termsOfService),
      ),
    AppRoutes.privacyPolicy => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const LegalDocumentScreen(document: privacyPolicy),
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
    AppRoutes.login => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const LoginMobileScreen(),
      ),
    AppRoutes.otpPhone => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) {
          final target = settings.arguments as String?;
          return PhoneOtpScreen(phoneNumber: target);
        },
      ),
    AppRoutes.otpEmail => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) {
          final target = settings.arguments as String?;
          return EmailOtpScreen(email: target);
        },
      ),
    AppRoutes.completeProfile => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const CompleteProfileScreen(),
      ),
    AppRoutes.doseReminder => MaterialPageRoute<DoseReminderResult>(
        settings: settings,
        fullscreenDialog: true,
        builder: (_) {
          final arguments = settings.arguments;
          if (arguments is! DoseReminderRouteArguments) {
            return const _InvalidDoseReminderRouteScreen();
          }
          return LockscreenPrivacyGate(
            platform: arguments.keyguardPlatform,
            child: DoseReminderScreen(arguments: arguments),
          );
        },
      ),
    AppRoutes.familyMyCode => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const FamilyLinkCodeScreen(),
      ),
    AppRoutes.familyShareLink => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const ShareInviteLinkScreen(),
      ),
    AppRoutes.familyScanCode => MaterialPageRoute<void>(
        settings: settings,
        fullscreenDialog: true,
        builder: (_) => const ScanLinkQrScreen(),
      ),
    AppRoutes.familyEnterCode => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => EnterLinkCodeScreen(
          args: settings.arguments as EnterLinkCodeArgs? ??
              const EnterLinkCodeArgs(),
        ),
      ),
    AppRoutes.familyLinkResult => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => LinkRequestResultScreen(
          outcome: settings.arguments as LinkSubmitOutcome? ??
              LinkSubmitOutcome.waiting,
        ),
      ),
    AppRoutes.linkConsentConfirmation => MaterialPageRoute<bool>(
        settings: settings,
        builder: (context) {
          final args = settings.arguments;
          if (args is! LinkConsentConfirmationArgs) {
            return const Scaffold(
              body: Center(child: Text('Yêu cầu không hợp lệ')),
            );
          }
          return LinkConsentConfirmationScreen(args: args);
        },
      ),
    _ => null,
  };
}

/// Safe fallback when a notification opens the route without typed arguments.
class _InvalidDoseReminderRouteScreen extends StatelessWidget {
  const _InvalidDoseReminderRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhắc uống thuốc')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Không thể mở thông tin liều thuốc.',
                style: AppTextStyles.bodyStrong,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
