import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/consent/presentation/screens/legal_document_screen.dart';
import 'package:drugtime_mobile/features/consent/presentation/widgets/legal_texts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AC18: hai văn bản pháp lý hiển thị đủ, đúng phiên bản, không còn placeholder.
void main() {
  Future<void> pumpDocument(WidgetTester tester, LegalDocument document,
      {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(home: LegalDocumentScreen(document: document)));
    await tester.pumpAndSettle();
  }

  Iterable<String> allStrings(LegalDocument d) => [
        d.title,
        if (d.intro != null) d.intro!,
        for (final s in d.sections) ...[s.heading, ...s.paragraphs],
      ];

  for (final (document, sectionCount) in [(termsOfService, 10), (privacyPolicy, 9)]) {
    group(document.title, () {
      test('phiên bản trùng phiên bản app gửi khi đồng ý, đủ mục', () {
        expect(document.version, termsDocumentVersion);
        expect(document.version, '2026-10-v1');
        expect(document.effectiveDate, '01/10/2026');
        expect(document.sections, hasLength(sectionCount));
        for (final (i, section) in document.sections.indexed) {
          expect(section.heading, startsWith('${i + 1}. '));
          expect(section.paragraphs, isNotEmpty);
        }
      });

      test('không còn placeholder hay ghi chú nội bộ', () {
        for (final text in allStrings(document)) {
          expect(text, isNot(contains('[')), reason: text);
          expect(text, isNot(contains(']')), reason: text);
          expect(text, isNot(contains('Team')), reason: text);
          expect(text, isNot(contains('pháp lý rà soát')), reason: text);
          expect(text, isNot(contains('**')), reason: text);
        }
      });

      testWidgets('hiển thị tiêu đề, phiên bản và mọi heading (cuộn được)', (tester) async {
        await pumpDocument(tester, document);

        expect(find.widgetWithText(AppBar, document.title), findsOneWidget);
        expect(find.text('Phiên bản 2026-10-v1 · Hiệu lực từ 01/10/2026'), findsOneWidget);
        for (final section in document.sections) {
          await tester.scrollUntilVisible(find.text(section.heading), 300,
              scrollable: find.byType(Scrollable).first);
          expect(find.text(section.heading), findsOneWidget);
        }
      });

      testWidgets('cỡ chữ 2.0: không tràn', (tester) async {
        await pumpDocument(tester, document, textScale: 2.0);
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  }

  test('liên hệ dùng đúng email đã chốt; mục trẻ em theo lựa chọn 16 tuổi', () {
    final terms = allStrings(termsOfService).join('\n');
    final privacy = allStrings(privacyPolicy).join('\n');
    expect(terms, contains('Email: drugtime@gmail.com'));
    expect(privacy, contains('Liên hệ về quyền riêng tư: drugtime@gmail.com.'));
    expect(privacy, contains('DrugTime hiện chỉ dành cho người từ đủ 16 tuổi.'));
    expect(terms, contains('gửi yêu cầu xóa dữ liệu qua email drugtime@gmail.com'));
  });
}
