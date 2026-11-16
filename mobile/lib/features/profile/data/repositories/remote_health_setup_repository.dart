import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/entities/health_setup.dart';
import '../../domain/repositories/health_setup_repository.dart';

class RemoteHealthSetupRepository implements HealthSetupRepository {
  RemoteHealthSetupRepository(this._api);
  final ApiClient _api;

  static const _path = '/profile/health-setup';

  Map<String, dynamic> _object(Object? data) => data as Map<String, dynamic>;

  HealthSetupStep<T> _step<T>(Object? data) {
    final json = _object(data);
    return switch (json['status']) {
      'unreported' => HealthSetupStep<T>(HealthSetupStatus.unreported),
      'none_known' => HealthSetupStep<T>(HealthSetupStatus.noneKnown),
      'reported' => HealthSetupStep<T>(
          HealthSetupStatus.reported,
          ids: List<T>.from(json['catalog_ids'] as List),
          names: List<String>.from(json['custom_names'] as List),
        ),
      _ => throw const FormatException('Unknown health setup status'),
    };
  }

  HealthSetupSnapshot _snapshot(Object? data) {
    final json = _object(data);
    final revision = json['revision'] as String;
    if (revision.isEmpty) {
      throw const FormatException('Missing profile revision');
    }
    return HealthSetupSnapshot(
      revision,
      _step<String>(json['allergies']),
      _step<int>(json['conditions']),
    );
  }

  Map<String, Object?> _encode<T>(HealthSetupStep<T> step) =>
      switch (step.status) {
        HealthSetupStatus.noneKnown => {'status': 'none_known'},
        HealthSetupStatus.reported => {
            'status': 'reported',
            'catalog_ids': step.ids,
            'custom_names': step.names,
          },
        HealthSetupStatus.unreported =>
          throw ArgumentError('Skipped steps must be omitted'),
      };

  @override
  Future<HealthSetupSnapshot> read() async =>
      _snapshot(await _api.getJson(_path));

  @override
  Future<List<HealthSetupOption<String>>> allergens() async {
    final body = _object(await _api.getJson('/allergens'));
    return (body['items'] as List).map((value) {
      final row = _object(value);
      final category = row['category'] as String;
      if (category != 'food' && category != 'drug') {
        throw const FormatException('Unknown allergen category');
      }
      return HealthSetupOption(row['id'] as String, row['name'] as String,
          category: category);
    }).toList();
  }

  @override
  Future<List<HealthSetupOption<int>>> conditions() async {
    final items = <int, HealthSetupOption<int>>{};
    var offset = 0;
    while (true) {
      final body = _object(await _api.getJson('/conditions',
          query: {'offset': '$offset', 'limit': '100'}));
      final rows = body['items'] as List;
      for (final value in rows) {
        final row = _object(value);
        final id = row['id'] as int;
        items[id] = HealthSetupOption(id, row['name'] as String);
      }
      offset += rows.length;
      if (offset >= (body['total'] as int)) return items.values.toList();
      if (rows.isEmpty) {
        throw const FormatException('Incomplete condition catalog');
      }
    }
  }

  @override
  Future<HealthSetupSnapshot> save(
    String revision, {
    HealthSetupStep<String>? allergies,
    HealthSetupStep<int>? conditions,
  }) async {
    try {
      return _snapshot(await _api.putJson(
        _path,
        body: {
          'revision': revision,
          if (allergies != null) 'allergies': _encode(allergies),
          if (conditions != null) 'conditions': _encode(conditions),
        },
        expectedStatus: 200,
      ));
    } on ApiException catch (error) {
      throw HealthSetupSaveException(
          needsReadback: error.statusCode == 409 ||
              error.statusCode == null ||
              error.isTransient ||
              (error.statusCode ?? 0) >= 500);
    } on FormatException {
      throw const HealthSetupSaveException(needsReadback: true);
    } on TypeError {
      throw const HealthSetupSaveException(needsReadback: true);
    }
  }
}
