import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drugtime_mobile/app/app.dart';
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/core/api/api_client.dart';
import 'package:drugtime_mobile/core/config/app_config.dart';
import 'package:drugtime_mobile/features/adherence/data/repositories/remote_adherence_repository.dart';
import 'package:drugtime_mobile/features/auth/data/repositories/in_memory_auth_repository.dart';
import 'package:drugtime_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:drugtime_mobile/features/auth/presentation/state/auth_controller.dart';
import 'package:drugtime_mobile/features/consent/data/repositories/in_memory_consent_repository.dart';
import 'package:drugtime_mobile/features/consent/domain/entities/consent.dart';
import 'package:drugtime_mobile/features/medication/data/repositories/in_memory_medication_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

// The stage-test runner must build this isolated package and install its fixture
// with adb run-as. No fixture, bearer, or health data is written into app assets.
const historyPrivateRoot = '/data/data/vn.drugtime.adherence_e2e/files';
const _fixturePath = '$historyPrivateRoot/adherence_fixture.json';
const _phasePath = '$historyPrivateRoot/adherence_phase.json';
const _commandPath = '$historyPrivateRoot/adherence_command.json';

class HistoryFixture {
  const HistoryFixture(this.session, this.patient, this.otherPatient,
      this.medicationName, this.scenario);

  final AuthSession session;
  final String patient;
  final String otherPatient;
  final String medicationName;
  final String scenario;

  static Future<HistoryFixture> read() async {
    try {
      final json = jsonDecode(await File(_fixturePath).readAsString())
          as Map<String, dynamic>;
      final session =
          AuthSession.fromJson(json['session'] as Map<String, dynamic>);
      final patient = json['patient_id'] as String;
      final other = json['other_patient_id'] as String;
      final medicine = json['medication_name'] as String;
      final scenario = json['scenario'] as String;
      final uuid = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (!uuid.hasMatch(patient) ||
          !uuid.hasMatch(other) ||
          !uuid.hasMatch(session.userId) ||
          patient == other ||
          patient == session.userId ||
          session.accessToken.isEmpty ||
          session.isExpired ||
          !session.profileComplete ||
          session.sessionType != 'mobile' ||
          medicine.trim().isEmpty ||
          !{'linked', 'revoke', 'cross_patient'}.contains(scenario)) {
        throw const FormatException();
      }
      return HistoryFixture(session, patient, other, medicine, scenario);
    } on Object {
      // Do not include the caught error: JSON parse errors can contain a bearer.
      throw StateError('Local adherence fixture is missing or invalid');
    }
  }
}

class HistoryCall {
  const HistoryCall(this.method, this.patient, this.status);
  final String method;
  final String? patient;
  final int status;
}

class _ObservedClient extends http.BaseClient {
  final _inner = http.Client();
  final calls = <HistoryCall>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    calls.add(HistoryCall(request.method,
        request.url.queryParameters['patient_id'], response.statusCode));
    return response;
  }

  @override
  void close() => _inner.close();
}

class HistoryHarness {
  HistoryHarness(this.fixture);
  final HistoryFixture fixture;
  final navigator = GlobalKey<NavigatorState>();
  final _http = _ObservedClient();
  late final auth = AuthController(InMemoryAuthRepository(
    simulatedDelay: Duration.zero,
    initialSession: fixture.session,
  ));

  List<HistoryCall> get calls => List.unmodifiable(_http.calls);

  Future<void> start(WidgetTester tester) async {
    final endpoint = Uri.tryParse(AppConfig.apiBaseUrl);
    if (endpoint == null ||
        endpoint.scheme != 'http' ||
        !{'127.0.0.1', 'localhost', '10.0.2.2'}.contains(endpoint.host)) {
      throw StateError('Adherence E2E requires a local HTTP backend');
    }
    final api = ApiClient(
      baseUrl: endpoint,
      httpClient: _http,
      authTokenProvider: () async => auth.currentSession?.accessToken,
      onUnauthorized: auth.handleUnauthorized,
    );
    // Only bootstrap auth, medication and consent use in-memory collaborators.
    // History uses the production route/controller/repository and real HTTP;
    // backend PEP and consent are never replaced by the Flutter harness.
    await tester.pumpWidget(DrugTimeApp(
      authController: auth,
      navigatorKey: navigator,
      adherenceRepository: RemoteAdherenceRepository(api),
      medicationRepository: InMemoryMedicationRepository(),
      consentRepository: InMemoryConsentRepository(
          granted: {ConsentPurpose.terms, ConsentPurpose.healthData}),
    ));
    await waitForHistory(tester, () => navigator.currentState != null,
        step: 'session-ready');
    openPatient(fixture.patient);
  }

  void openPatient(String patient) {
    // Tests the real named route. It does not certify a patient-selector UI.
    unawaited(navigator.currentState!.pushNamed(AppRoutes.familyAdherence,
        arguments: FamilyAdherenceRouteArgs(patientId: patient)));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    _http.close();
    for (final path in [_fixturePath, _phasePath, _commandPath]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}

Future<void> waitForHistory(WidgetTester tester, bool Function() ready,
    {required String step}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
  }
  fail('Adherence E2E step timed out: $step');
}

Future<void> signalHistoryLoaded() =>
    File(_phasePath).writeAsString('{"phase":"history_loaded"}', flush: true);

Future<void> waitForRevocation() async {
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    final file = File(_commandPath);
    if (await file.exists()) {
      // Runner writes atomically inside isolated private storage; malformed
      // control data is a failure rather than an implicit permission to proceed.
      final command = jsonDecode(await file.readAsString());
      if (command is Map && command['command'] == 'revocation_committed') {
        return;
      }
      throw StateError('Unexpected adherence runner command');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Adherence runner did not confirm a committed revocation');
}
