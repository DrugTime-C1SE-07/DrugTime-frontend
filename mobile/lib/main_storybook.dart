import 'package:flutter/material.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

// Thay thế import cũ bằng đường dẫn tương đối (lùi từ vị trí file ra thư mục lib)
import 'features/auth/login_screen.dart'; 
import 'features/medication/add_medication_form.dart'; 

void main() {
  runApp(const MyStorybookApp());
}

class MyStorybookApp extends StatelessWidget {
  const MyStorybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Storybook(
      stories: [
        Story(
          name: 'Authentication/Login Screen',
          description: 'Giao diện màn hình đăng nhập',
          builder: (context) => const LoginScreen(), 
        ),
        Story(
          name: 'Medication/Add Form UI',
          description: 'Giao diện thêm lịch uống thuốc',
          builder: (context) => const AddMedicationForm(), // Xóa chữ const nếu file AddMedicationForm báo lỗi không phải hằng số
        ),
      ],
    );
  }
}
