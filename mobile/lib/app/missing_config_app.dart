import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

/// Hiện khi build thiếu `DRUGTIME_API_BASE_URL`, thay vì âm thầm chạy với dữ liệu giả.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thiếu cấu hình máy chủ', style: AppTextStyles.title),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Bản build này chưa có địa chỉ Backend API. Copy .env.example '
                  'thành .env.android (hoặc .env.web) rồi chạy lại với '
                  '--dart-define-from-file=.env.android.',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
