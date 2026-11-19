import 'dart:async';

import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/app_shell.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/login_method.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/login_mobile_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/data/sources/invite_link_source.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/enter_link_code_screen.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _validLink = 'https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR4';

class _FakeInviteLinkSource implements InviteLinkSource {
  final controller = StreamController<Uri>.broadcast(sync: true);

  @override
  Stream<Uri> get links => controller.stream;

  void open(String link) => controller.add(Uri.parse(link));
}

AuthSession _session() => AuthSession(
      userId: 'u-1',
      accessToken: 'app-token',
      expiresAt: DateTime.now().add(const Duration(days: 10)),
      profileComplete: true,
    );

String _fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('link-code-field')))
    .controller!
    .text;

void main() {
  late _FakeInviteLinkSource links;
  late InMemoryFamilyLinkRepository familyLinks;

  setUp(() {
    links = _FakeInviteLinkSource();
    familyLinks = InMemoryFamilyLinkRepository();
  });

  tearDown(() => links.controller.close());

  Future<AuthController> pumpApp(
    WidgetTester tester, {
    AuthSession? session,
    AuthController? controller,
    String? initialRoute,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = controller ??
        AuthController(InMemoryAuthRepository(
            initialSession: session, simulatedDelay: Duration.zero));
    await tester.pumpWidget(DrugTimeApp(
      authController: auth,
      medicationRepository: InMemoryMedicationRepository(),
      familyLinkRepository: familyLinks,
      inviteLinkSource: links,
      initialRoute: initialRoute,
    ));
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('AC16: đã đăng nhập, mở link mời → màn nhập mã điền sẵn, chưa gửi',
      (tester) async {
    await pumpApp(tester, session: _session());
    expect(find.byType(AppShell), findsOneWidget);

    links.open(_validLink);
    await tester.pumpAndSettle();

    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
    expect(_fieldText(tester), 'K7M2 Q9XA R4');
    expect(familyLinks.calls, isEmpty);

    await tester.tap(find.byKey(const Key('link-code-submit')));
    await tester.pumpAndSettle();
    expect(familyLinks.calls.single.code, 'K7M2Q9XAR4');
  });

  testWidgets('AC16: chưa đăng nhập → đăng nhập OTP xong mới tới màn nhập mã với đúng mã',
      (tester) async {
    final repo = InMemoryAuthRepository(simulatedDelay: Duration.zero);
    final auth = AuthController(repo)..setMethod(LoginMethod.email);
    await auth.requestOtp('lan@example.com');
    await pumpApp(tester, controller: auth, initialRoute: AppRoutes.otpEmail);

    links.open(_validLink);
    await tester.pumpAndSettle();
    expect(find.byType(EnterLinkCodeScreen), findsNothing);

    await tester.enterText(
      find.descendant(of: find.byType(OtpVerificationScreen), matching: find.byType(TextField)),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
    expect(_fieldText(tester), 'K7M2 Q9XA R4');
    expect(familyLinks.calls, isEmpty);
  });

  testWidgets('AC15, AC16: link sai → màn nhập mã trống kèm "Link mời không hợp lệ"',
      (tester) async {
    await pumpApp(tester, session: _session());

    links.open('https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR0');
    await tester.pumpAndSettle();

    expect(find.byType(EnterLinkCodeScreen), findsOneWidget);
    expect(find.text('Link mời không hợp lệ.'), findsOneWidget);
    expect(_fieldText(tester), isEmpty);
  });

  testWidgets('đăng xuất xóa link mời đang chờ', (tester) async {
    // Đã đăng nhập nhưng còn ở màn hoàn thiện hồ sơ: shell chưa dựng nên link nằm chờ.
    final repo = InMemoryAuthRepository(
      initialSession: AuthSession(
        userId: 'u-1',
        accessToken: 'app-token',
        expiresAt: DateTime.now().add(const Duration(days: 10)),
        profileComplete: false,
      ),
      simulatedDelay: Duration.zero,
    );
    final auth = AuthController(repo);
    await pumpApp(tester, controller: auth);
    expect(find.byType(AppShell), findsNothing);

    links.open(_validLink);
    await tester.pumpAndSettle();
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginMobileScreen), findsOneWidget);

    // Đăng nhập lại trong cùng app (giữ nguyên InviteLinkController).
    auth.setMethod(LoginMethod.email);
    await auth.requestOtp('lan@example.com');
    unawaited(tester.state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.otpEmail));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(OtpVerificationScreen), matching: find.byType(TextField)),
      '123456',
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(EnterLinkCodeScreen), findsNothing);
  });
}
