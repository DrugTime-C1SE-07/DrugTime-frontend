import 'package:flutter/material.dart';

import '../features/medication/data/repositories/in_memory_medication_repository.dart';
import '../features/medication/domain/entities/medication.dart';
import '../features/medication/presentation/screens/edit_medication_screen.dart';
import '../features/medication/presentation/screens/medication_detail_screen.dart';
import '../features/medication/presentation/screens/add_medication_screen.dart';
import '../features/medication/presentation/screens/my_medications_screen.dart';
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
  static const devCatalog = '/dev-catalog';
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
    AppRoutes.devCatalog => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const DevUiCatalogScreen(),
      ),
    _ => null,
  };
}

/// Màn hình Catalog dành cho Developer / Tester để duyệt nhanh qua tất cả các UI
class DevUiCatalogScreen extends StatelessWidget {
  const DevUiCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screens = <_UiItem>[
      _UiItem(
        title: 'S00c · Đăng nhập (OTP / Email)',
        description:
            'Màn hình đăng nhập di động, chọn số điện thoại hoặc email',
        badge: 'Auth',
        route: AppRoutes.login,
      ),
      _UiItem(
        title: 'S00c-otp · Xác thực OTP (Số điện thoại)',
        description: 'Màn hình nhập mã OTP 6 số gửi qua tin nhắn SMS',
        badge: 'Auth',
        route: AppRoutes.otpPhone,
      ),
      _UiItem(
        title: 'S00c-otp-2 · Xác thực OTP (Email)',
        description: 'Màn hình nhập mã OTP 6 số gửi qua hòm thư điện tử',
        badge: 'Auth',
        route: AppRoutes.otpEmail,
      ),
      _UiItem(
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
      _UiItem(
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
