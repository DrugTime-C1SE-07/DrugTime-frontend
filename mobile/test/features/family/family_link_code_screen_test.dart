import 'package:drugtime_mobile/features/family/domain/entities/family_link_code.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code_failure.dart';
import 'package:drugtime_mobile/features/family/domain/repositories/family_link_code_repository.dart';
import 'package:drugtime_mobile/features/family/presentation/screens/family_link_code_screen.dart';
import 'package:drugtime_mobile/features/family/presentation/state/family_link_code_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _FakeRepository implements FamilyLinkCodeRepository {
  final List<Object> results;
  int calls = 0;

  _FakeRepository(this.results);

  @override
  Future<FamilyLinkCode> fetch() async {
    calls++;
    final result = results.removeAt(0);
    if (result is FamilyLinkCodeFailure) throw result;
    return result as FamilyLinkCode;
  }
}

Future<void> pumpScreen(
    WidgetTester tester, FamilyLinkCodeRepository repository) async {
  final controller = FamilyLinkCodeController(repository);
  await tester.pumpWidget(MaterialApp(
    home: FamilyLinkCodeScope(
        controller: controller, child: const FamilyLinkCodeScreen()),
  ));
  await tester.pumpAndSettle();
  addTearDown(controller.dispose);
}

void main() {
  testWidgets('hiển thị đúng code và QR dùng nguyên payload API',
      (tester) async {
    const payload = 'drugtime://link?code=A1B2C3D4E5';
    await pumpScreen(
        tester,
        _FakeRepository([
          const FamilyLinkCode(code: 'A1B2C3D4E5', qrPayload: payload),
        ]));

    expect(find.byKey(const Key('family-link-code')), findsOneWidget);
    expect(find.text('A1B2C3D4E5'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('Liên kết chỉ được tạo sau khi bạn chấp thuận'),
        findsOneWidget);
    expect(find.textContaining('đã liên kết'), findsNothing);
  });

  testWidgets('lỗi không lộ body và nút thử lại tải lại mã từ server',
      (tester) async {
    final repository = _FakeRepository([
      const FamilyLinkCodeFailure(FamilyLinkCodeFailureKind.unavailable),
      const FamilyLinkCode(
          code: 'F1G2H3J4K5', qrPayload: 'drugtime://link?code=F1G2H3J4K5'),
    ]);
    await pumpScreen(tester, repository);

    expect(find.text('Chưa thể tải mã liên kết. Vui lòng thử lại.'),
        findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('F1G2H3J4K5'), findsOneWidget);
  });
}
