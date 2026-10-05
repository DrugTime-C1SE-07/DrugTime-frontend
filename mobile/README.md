# DrugTime Mobile (Flutter)

Mobile client application for **DrugTime** — Medication Reminder and Care Platform.

---

## 1. Tech Stack & Architecture Overview
- **Framework**: [Flutter](https://flutter.dev) (SDK `>=3.0.0 <4.0.0`, Dart 3.x)
- **UI Architecture**: Material 3 + Centralized Design System (`lib/app/theme/app_theme.dart`)
- **State Management**: Clean Architecture with standard `ChangeNotifier` + `InheritedNotifier` (`Scope` pattern)
- **Networking**: Cross-platform HTTP Client (`package:http`) interfacing with FastAPI Backend
- **Testing**: `flutter_test` (Unit tests for Domain Entities & Widget tests for Screens)

---

## 2. Directory Architecture (Clean Architecture by Feature)

The project organizes all business domains under `lib/features/`, following standard Clean Architecture layers:

```text
mobile/
├── analysis_options.yaml           # Lint rules (flutter_lints)
├── pubspec.yaml                    # Package dependencies and assets
├── test/
│   ├── core/                       # Core utility tests
│   │   └── app_assets_test.dart
│   ├── features/
│   │   ├── auth/                   # Unit & Widget tests for Auth feature
│   │   │   ├── auth_entity_test.dart
│   │   │   └── login_screen_test.dart
│   │   └── medication/             # Unit & Widget tests for Medication feature
│   │       ├── medication_entity_test.dart
│   │       └── medication_screens_test.dart
│   ├── login_mobile_screen_test.dart
│   └── widget_test.dart
└── lib/
    ├── main.dart                   # Entry point (runApp DrugTimeApp)
    ├── app/
    │   ├── app.dart                # Root DrugTimeApp with AuthScope & MedicationScope
    │   ├── app_shell.dart          # 5-tab main application shell
    │   ├── router.dart             # Declarative route configuration (AppRoutes)
    │   └── theme/
    │       ├── app_theme.dart      # Canonical Design Tokens (AppColors, AppSpacing, AppTextStyles, AppShadows)
    │       └── simple_mode_theme.dart # High-contrast / Elderly accessibility theme
    ├── core/
    │   ├── api/                    # ApiClient, AuthInterceptor, ApiException
    │   ├── notification/           # Notification permissions & reminder scheduling
    │   ├── storage/                # Local SQLite DB & Secure Storage
    │   ├── utils/                  # AppAssets paths and helpers
    │   └── widgets/                # Core system widgets (status_bar_compact, home_indicator, vector_icons)
    ├── shared/
    │   └── widgets/                # Reusable cross-feature widgets (pill_icon, selectable_pill, etc.)
    └── features/
        ├── auth/                   # Authentication & Onboarding (Clean Architecture)
        │   ├── domain/
        │   │   ├── entities/
        │   │   │   ├── auth_session.dart        # AuthSession entity & token model
        │   │   │   └── login_method.dart        # LoginMethod enum & AuthValidator
        │   │   └── repositories/
        │   │       └── auth_repository.dart     # Abstract interface AuthRepository
        │   ├── data/
        │   │   ├── sources/
        │   │   │   └── auth_api_service.dart    # Remote API HTTP client (/auth/mobile/*)
        │   │   └── repositories/
        │   │       ├── in_memory_auth_repository.dart # Mock repository for tests & offline UI
        │   │       └── remote_auth_repository.dart    # Concrete repository calling backend API
        │   └── presentation/
        │       ├── state/
        │       │   └── auth_controller.dart     # AuthController + AuthScope
        │       ├── screens/
        │       │   ├── login_mobile_screen.dart # S00c · Đăng nhập (Số điện thoại / Email)
        │       │   ├── otp_verification_screen.dart # S00c-otp & S00c-otp-2 (Xác thực OTP)
        │       │   ├── phone_otp_screen.dart    # S00c-otp (Xác thực OTP SMS)
        │       │   └── email_otp_screen.dart    # S00c-otp-2 (Xác thực OTP Email)
        │       └── widgets/
        │           ├── login_header.dart        # 60x60 Logo + Heading + Subheading
        │           ├── login_segmented_picker.dart # Phone / Email tab switcher
        │           ├── phone_input_field.dart   # Phone input with +84 prefix & formatter
        │           ├── email_input_field.dart   # Email input with validation
        │           ├── trust_card.dart          # Healthcare compliance & encryption card
        │           ├── mascot_protect_widget.dart # 96x88 Mascot "Bảo Vệ"
        │           ├── otp_header.dart          # Mascot + Heading 20px + Subheading
        │           ├── otp_pin_input.dart       # 6-digit PIN input with active border
        │           └── otp_resend_row.dart      # Clock icon + 60s countdown timer
        └── medication/             # Medication Management (Clean Architecture)
            ├── domain/
            │   ├── entities/
            │   │   └── medication.dart
            │   └── repositories/
            │       └── medication_repository.dart
            ├── data/
            │   └── repositories/
            │       └── in_memory_medication_repository.dart
            └── presentation/
                ├── state/
                │   └── medication_controller.dart # MedicationController + MedicationScope
                ├── screens/
                │   ├── my_medications_screen.dart
                │   └── add_medication_screen.dart
                └── widgets/
                    ├── drug_catalog_sheet.dart
                    ├── medication_card.dart
                    ├── medication_filter_bar.dart
                    ├── medication_form_fields.dart
                    ├── medication_labels.dart
                    └── medication_notices.dart
```

---

## 3. Standardization Highlights in `features/auth/`

1. **Domain Layer Independence**:
   - `AuthSession`: Pure Dart entity handling tokens, expiration, and JSON mapping.
   - `LoginMethod` & `AuthValidator`: Pure Dart validator for Vietnamese mobile numbers (E.164 normalization `+84...`) and RFC-compliant email checks.
   - `AuthRepository`: `abstract interface class` defining authentication contracts decoupled from any network or storage framework.

2. **Pluggable Data Layer**:
   - `InMemoryAuthRepository`: In-memory implementation enabling offline testing and standalone UI preview.
   - `RemoteAuthRepository`: Connects directly to backend FastAPI identity endpoints via `AuthApiService`.

3. **Predictable Presentation Layer**:
   - `AuthController`: Inherits from `ChangeNotifier`, providing clean loading states, error handling, and method toggling.
   - `AuthScope`: Inherits from `InheritedNotifier`, allowing widgets anywhere in the subtree to observe or trigger auth actions (`AuthScope.of(context)` / `AuthScope.read(context)`).
   - `LoginMobileScreen`: Aligned with `AppColors`, `AppSpacing`, `AppRadius`, `AppTextStyles`, and `AppShadows` from `app_theme.dart`.

4. **Integration with `DrugTimeApp`**:
   - Both `AuthScope` and `MedicationScope` wrap `MaterialApp`, ensuring controllers are accessible across screens, dialogs, and bottom sheets.
   - `AppRoutes.login` (`/login`) is registered in `router.dart`.

---

## 4. How to Run & Test

```bash
cd mobile
flutter pub get

# Run all unit and widget tests:
flutter test

```

### Cấu hình địa chỉ Backend API (`.env`)

App không có địa chỉ backend mặc định: chạy thiếu cấu hình sẽ hiện màn "Thiếu cấu hình máy chủ".
Địa chỉ được đóng vào app lúc build qua `--dart-define-from-file` (Flutter không tự đọc `.env`).

1. Copy file mẫu (các file `.env.*` khác đã có trong `.gitignore`, không commit):
   ```bash
   cp .env.example .env.android   # DRUGTIME_API_BASE_URL=http://10.0.2.2:8000
   cp .env.example .env.web       # sửa thành DRUGTIME_API_BASE_URL=http://127.0.0.1:8001
   ```
2. Chạy:

   | Thiết bị | File | Lệnh |
   |---|---|---|
   | Android emulator | `.env.android` = `http://10.0.2.2:8000` | `flutter run -d emulator-5554 --dart-define-from-file=.env.android` |
   | Chrome | `.env.web` = địa chỉ backend có CORS cho `http://localhost:5000` | `flutter run -d chrome --web-port 5000 --dart-define-from-file=.env.web` |
   | Điện thoại thật (USB) | `http://127.0.0.1:8000` | `adb reverse tcp:8000 tcp:8000` rồi `flutter run --dart-define-from-file=<file>` |

   - Emulator: `10.0.2.2` là máy tính chạy backend (`127.0.0.1` là chính emulator).
   - Chrome: backend phải có `CORS_ALLOWED_ORIGINS=http://localhost:5000,http://127.0.0.1:5000`, và phải giữ `--web-port 5000`.
3. Nút Run của IDE: thêm `--dart-define-from-file=.env.android` vào *Additional run args* (Android Studio)
   hoặc `"args": ["--dart-define-from-file=.env.android"]` trong `.vscode/launch.json` (VS Code).

File `.env.*` chỉ được chứa địa chỉ Backend API. Không ghi key hay secret: giá trị bị đóng vào app và đọc được từ file cài đặt.

