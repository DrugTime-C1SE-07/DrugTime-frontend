import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/features/profile/data/repositories/profile_preview_repository.dart';
import 'package:drugtime_mobile/features/profile/data/repositories/profile_repository_provider.dart';
import 'package:drugtime_mobile/features/profile/data/repositories/remote_profile_repository.dart';
import 'package:drugtime_mobile/features/profile/domain/entities/health_profile.dart';

void main() {
  test('preview repository provides and locally edits demo profile data',
      () async {
    final repository = ProfilePreviewRepository();
    final initial = await repository.fetch();

    expect(initial.fullName, 'Nguyễn Minh Anh');
    expect(initial.email, 'minh.anh@example.com');
    expect(initial.conditions, hasLength(1));
    await repository.update(ProfileDraft(
      fullName: 'Tên xem trước',
      dateOfBirth: DateTime(1990, 2, 3),
      gender: 'nam',
      email: 'new@example.com',
    ));
    expect((await repository.fetch()).fullName, 'Tên xem trước');
    expect((await repository.fetch()).email, 'new@example.com');

    final page = await repository.catalog(offset: 0, limit: 2);
    expect(page.items, hasLength(2));
    expect(page.total, greaterThan(page.items.length));
    final added = await repository.addCondition(2);
    expect(added.name, 'Đái tháo đường');
    final updated = await repository.updateCondition(
      added.id,
      {'stage': 'II'},
    );
    expect(updated.stage, 'II');
    await repository.deleteCondition(added.id);
    expect((await repository.fetch()).conditions, hasLength(1));
  });

  test('preview mode is opt-in and normal mode keeps remote API repository',
      () async {
    var requests = 0;
    final api = ApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:1'),
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );

    expect(createProfileRepository(api), isA<RemoteProfileRepository>());
    final preview = createProfileRepository(api, previewMode: true);
    expect(preview, isA<ProfilePreviewRepository>());
    await preview.fetch();
    await preview.catalog(offset: 0);
    expect(requests, 0);
    expect(
      createProfileRepository(api, previewMode: false),
      isA<RemoteProfileRepository>(),
    );
  });
}
