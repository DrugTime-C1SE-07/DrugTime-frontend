import 'package:flutter/material.dart';

import '../features/consent/presentation/screens/consent_screen.dart';
import '../features/consent/presentation/screens/legal_document_screen.dart';
import '../features/consent/presentation/screens/privacy_settings_screen.dart';
import '../features/consent/presentation/widgets/consent_gate.dart';
import '../features/consent/presentation/widgets/legal_texts.dart';
import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/entities/medication.dart';
import '../features/medication/presentation/screens/edit_medication_screen.dart';
import '../features/medication/presentation/screens/medication_detail_screen.dart';
import '../features/medication/presentation/screens/add_medication_screen.dart';
import '../features/medication/presentation/screens/my_medications_screen.dart';
import '../features/reminder/domain/entities/dose_reminder.dart';
import '../features/reminder/presentation/screens/dose_reminder_screen.dart';
import '../features/reminder/presentation/widgets/lockscreen_privacy_gate.dart';
import '../features/auth/presentation/screens/complete_profile_screen.dart';
import '../features/auth/presentation/screens/email_otp_screen.dart';
import '../features/auth/presentation/screens/login_mobile_screen.dart';
import '../features/auth/presentation/screens/phone_otp_screen.dart';
import 'app_shell.dart';
import 'theme/app_theme.dart';

abstract final class AppRoutes {
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
  static const devCatalog = '/dev-catalog';
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  return switch (settings.name) {
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
            child: DoseReminderScreen(arguments: arguments),
          );
        },
      ),
    AppRoutes.devCatalog => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const DevUiCatalogScreen(),
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

/// Màn hình Catalog dành cho Developer / Tester để duyệt nhanh qua tất cả các UI
class DevUiCatalogScreen extends StatelessWidget {
  const DevUiCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screens = <_UiItem>[
      const _UiItem(
        title: 'S00c · Đăng nhập (OTP / Email)',
        description:
            'Màn hình đăng nhập di động, chọn số điện thoại hoặc email',
        badge: 'Auth',
        route: AppRoutes.login,
      ),
      const _UiItem(
        title: 'S00c-otp · Xác thực OTP (Số điện thoại)',
        description: 'Màn hình nhập mã OTP 6 số gửi qua tin nhắn SMS',
        badge: 'Auth',
        route: AppRoutes.otpPhone,
      ),
      const _UiItem(
        title: 'S00c-otp-2 · Xác thực OTP (Email)',
        description: 'Màn hình nhập mã OTP 6 số gửi qua hòm thư điện tử',
        badge: 'Auth',
        route: AppRoutes.otpEmail,
      ),
      const _UiItem(
        title: 'Điều khoản dịch vụ',
        description: 'Văn bản điều khoản, mở từ ô tick ở màn đăng nhập',
        badge: 'Legal',
        route: AppRoutes.termsOfService,
      ),
      const _UiItem(
        title: 'Chính sách quyền riêng tư',
        description: 'Văn bản chính sách, mở từ ô tick ở màn đăng nhập',
        badge: 'Legal',
        route: AppRoutes.privacyPolicy,
      ),
      const _UiItem(
        title: 'App Shell (Chính 5 tabs)',
        description: 'Khung điều hướng đáy (Thuốc, Trang chủ, Lịch nhắc...)',
        badge: 'Core',
        route: AppRoutes.home,
      ),
      _UiItem(
        title: 'S06 · Thuốc của tôi',
        description: 'Danh sách thuốc đang dùng, cảnh báo sắp hết, bộ lọc',
        badge: 'Medication',
        builder: (_) =>
            const Scaffold(body: SafeArea(child: MyMedicationsScreen())),
      ),
      const _UiItem(
        title: 'S07 · Thêm thuốc mới',
        description: 'Form tìm dược thư, liều lượng, lịch nhắc, lưu trữ',
        badge: 'Medication',
        route: AppRoutes.addMedication,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Dev Catalog · DrugTime'),
        backgroundColor: AppColors.canvas,
        centerTitle: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: screens.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = screens[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: const BorderSide(color: AppColors.border),
            ),
            color: AppColors.surface,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () {
                if (item.route != null) {
                  Navigator.of(context).pushNamed(item.route!);
                } else if (item.builder != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: item.builder!),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandTint,
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                child: Text(
                                  item.badge,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: AppTextStyles.bodyStrong,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            item.description,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UiItem {
  const _UiItem({
    required this.title,
    required this.description,
    required this.badge,
    this.route,
    this.builder,
  });

  final String title;
  final String description;
  final String badge;
  final String? route;
  final WidgetBuilder? builder;
}
