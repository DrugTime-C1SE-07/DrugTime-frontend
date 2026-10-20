import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/privacy_settings_screen.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code_failure.dart';
import 'package:drugtime_mobile/features/family_link/data/repositories/in_memory_family_link_repository.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/family_tab_screen.dart';
import 'package:drugtime_mobile/features/family_link/presentation/screens/share_invite_link_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_link_test_helpers.dart';

const _link = 'https://drug-time-frontend.vercel.app/link#code=K7M2Q9XAR4';

void main() {
  late FakeInviteLinkSharer sharer;

  setUp(() => sharer = FakeInviteLinkSharer());

  Future<void> pumpShare(
    WidgetTester tester, {
    Set<ConsentPurpose>? consents,
    List<Object>? codes,
  }) async {
    await pumpFamilyLink(
      tester,
      const ShareInviteLinkScreen(),
      repository: InMemoryFamilyLinkRepository(),
      sharer: sharer,
      codeRepository: FakeFamilyLinkCodeRepository(codes),
      consents: consents ??
          const {ConsentPurpose.healthData, ConsentPurpose.familySharing, ConsentPurpose.terms},
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC22: từ tab Người thân mở Gửi link mời, hiện đúng link từ mã', (tester) async {
    await pumpFamilyLink(
      tester,
      const FamilyTabScreen(),
      repository: InMemoryFamilyLinkRepository(),
      sharer: sharer,
    );

    await tester.tap(find.byKey(const Key('family-share-link')));
    await tester.pumpAndSettle();

    expect(find.byType(ShareInviteLinkScreen), findsOneWidget);
    expect(find.text(_link), findsOneWidget);
  });

  testWidgets('AC22: Chia sẻ gửi đúng một chuỗi chứa link, không có tên', (tester) async {
    await pumpShare(tester);

    await tester.tap(find.byKey(const Key('invite-share')));
    await tester.pump();

    expect(sharer.shared, hasLength(1));
    expect(sharer.shared.single, inviteShareText(_link));
    expect(sharer.shared.single, contains(_link));
  });

  testWidgets('AC22: Sao chép link ghi đúng link vào clipboard', (tester) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text']);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpShare(tester);

    await tester.tap(find.byKey(const Key('invite-copy')));
    await tester.pump();

    expect(copied, [_link]);
    expect(find.text('Đã sao chép link'), findsOneWidget);
    expect(sharer.shared, isEmpty);
  });

  testWidgets('AC23: chưa đồng ý family_sharing → cảnh báo, mở được Quyền riêng tư, vẫn chia sẻ',
      (tester) async {
    await pumpShare(tester, consents: const {ConsentPurpose.healthData, ConsentPurpose.terms});

    expect(find.byKey(const Key('invite-sharing-off')), findsOneWidget);
    expect(find.byKey(const Key('invite-share')), findsOneWidget);

    await tester.tap(find.byKey(const Key('invite-open-privacy')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacySettingsScreen), findsOneWidget);
  });

  testWidgets('AC23: đã đồng ý family_sharing → không cảnh báo', (tester) async {
    await pumpShare(tester);

    expect(find.byKey(const Key('invite-sharing-off')), findsNothing);
  });

  testWidgets('AC23: tải mã lỗi → thông báo + Thử lại, không có link hay nút chia sẻ',
      (tester) async {
    await pumpShare(tester, codes: [
      const FamilyLinkCodeFailure(FamilyLinkCodeFailureKind.unavailable),
    ]);

    expect(find.byKey(const Key('invite-load-error')), findsOneWidget);
    expect(find.byKey(const Key('invite-link')), findsNothing);
    expect(find.byKey(const Key('invite-share')), findsNothing);
    expect(find.byKey(const Key('invite-copy')), findsNothing);

    await tester.tap(find.byKey(const Key('invite-retry')));
    await tester.pumpAndSettle();
    expect(find.text(_link), findsOneWidget);
  });
}
