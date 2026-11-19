import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/app/app_preview_session.dart';
import 'package:drugtime_mobile/features/adherence_history/domain/entities/adherence_history.dart';

void main() {
  test('clock captures Vietnam launch date at 14:00 across month/year/timezone',
      () {
    for (final input in ['2026-12-31T17:01:00Z', '2027-01-01T00:01:00+07:00']) {
      final s = AppPreviewSession(now: DateTime.parse(input));
      expect(s.clock, DateTime.utc(2027, 1, 1, 7));
      s.dispose();
    }
  });
  test(
      'identity, clock and memory dependencies are per epoch; signout clears auth',
      () async {
    var loggedOut = false;
    final s = AppPreviewSession(
        now: DateTime.utc(2026, 10, 22), onLogout: () => loggedOut = true);
    await s.auth.initSession();
    expect(s.auth.currentSession!.userId, 'adherence-demo');
    final data = await s.history.fetch(
        from: DateTime.utc(2026, 10, 1),
        to: DateTime.utc(2026, 10, 22),
        mode: HistoryMode.date);
    expect(data.patientId, s.auth.currentSession!.userId);
    final day = data.dates.last.summary;
    expect((day.taken, day.late, day.missed, day.pending, day.rate),
        (3, 1, 1, 1, 80));
    await s.auth.signOut();
    expect(loggedOut, true);
    expect(s.auth.currentSession, isNull);
    s.dispose();
    final next = AppPreviewSession(
        now: DateTime.utc(2026, 10, 23), authenticated: false);
    await next.auth.initSession();
    expect(next.auth.isAuthenticated, false);
    expect(next.clock, DateTime.utc(2026, 10, 23, 7));
    next.dispose();
  });
}
