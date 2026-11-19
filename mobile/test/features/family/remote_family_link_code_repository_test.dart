import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/family/data/repositories/remote_family_link_code_repository.dart';
import 'package:drugtime_mobile/features/family/domain/entities/family_link_code_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late List<(String, Uri, String?)> requests;
  late List<(int, Object?)> replies;
  late int unauthorizedCalls;
  late RemoteFamilyLinkCodeRepository repository;

  setUp(() async {
    requests = [];
    replies = [];
    unauthorizedCalls = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add((
        request.method,
        request.uri,
        request.headers.value(HttpHeaders.authorizationHeader)
      ));
      final (status, body) = replies.removeAt(0);
      request.response.statusCode = status;
      if (body != null) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
      }
      await request.response.close();
    });
    repository = RemoteFamilyLinkCodeRepository(ApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      authTokenProvider: () async => 'session-token',
      onUnauthorized: () async => unauthorizedCalls++,
    ));
  });

  tearDown(() => server.close(force: true));

  test('GET gửi bearer token và giữ nguyên code cùng qr_payload', () async {
    replies.add((
      200,
      {'code': 'A1B2C3D4E5', 'qr_payload': 'drugtime://link?code=A1B2C3D4E5'}
    ));

    final result = await repository.fetch();

    expect(result.code, 'A1B2C3D4E5');
    expect(result.qrPayload, 'drugtime://link?code=A1B2C3D4E5');
    expect(requests.single.$1, 'GET');
    expect(requests.single.$2.path, '/family/link-code');
    expect(requests.single.$3, 'Bearer session-token');
  });

  test('401, 403, 503 chuyển thành failure ổn định và 401 báo auth handler',
      () async {
    replies
      ..add((401, {'detail': 'sensitive response'}))
      ..add((403, {'detail': 'forbidden'}))
      ..add((503, {'detail': 'unavailable'}));

    for (final kind in [
      FamilyLinkCodeFailureKind.unauthorized,
      FamilyLinkCodeFailureKind.forbidden,
      FamilyLinkCodeFailureKind.unavailable,
    ]) {
      await expectLater(
        repository.fetch(),
        throwsA(isA<FamilyLinkCodeFailure>()
            .having((failure) => failure.kind, 'kind', kind)),
      );
    }
    expect(unauthorizedCalls, 1);
  });

  test('response thiếu trường không được trả thành dữ liệu', () async {
    replies.add((200, {'code': 'A1B2C3D4E5'}));

    await expectLater(
      repository.fetch(),
      throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
          'kind', FamilyLinkCodeFailureKind.invalidResponse)),
    );
  });

  test('lỗi mạng chuyển thành network failure', () async {
    await server.close(force: true);

    await expectLater(
      repository.fetch(),
      throwsA(isA<FamilyLinkCodeFailure>().having((failure) => failure.kind,
          'kind', FamilyLinkCodeFailureKind.network)),
    );
  });
}
