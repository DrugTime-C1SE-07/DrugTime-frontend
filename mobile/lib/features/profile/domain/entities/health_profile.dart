import 'condition.dart';

class HealthProfile {
  const HealthProfile(
      {this.fullName,
      this.dateOfBirth,
      this.gender,
      this.conditions = const []});
  final String? fullName;

  /// Calendar date, never an instant to convert between time zones.
  final DateTime? dateOfBirth;
  final String? gender;
  final List<ProfileCondition> conditions;
}

class ProfileDraft {
  const ProfileDraft(
      {required this.fullName,
      required this.dateOfBirth,
      required this.gender,});
  final String fullName;
  final DateTime dateOfBirth;
  final String gender;

  static DateTime todayInVietnam(DateTime now) {
    final vietnam = now.toUtc().add(const Duration(hours: 7));
    return DateTime(vietnam.year, vietnam.month, vietnam.day);
  }

  static String? validateName(String name) =>
      name.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null;

  static String? validateDate(DateTime? date, DateTime now) {
    if (date == null) return 'Vui lòng chọn ngày sinh';
    final calendar = DateTime(date.year, date.month, date.day);
    final today = todayInVietnam(now);

    if (calendar.isAfter(today)){
      return 'Ngày sinh không được ở tương lai';
    }
    
    if (today.year - calendar.year > 100){
      return 'Ngày sinh không hợp lệ';
    }

    return null;
  }

  static String? validateEmail(String email){
    final value = email.trim();
    if (value.isEmpty) return null;

    final emailPattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailPattern.hasMatch(value)) {
      return 'Email không hợp lệ';
    }
    return null;
  }
}
