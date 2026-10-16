import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drugtime_mobile/core/platform/keyguard_service.dart';
import 'package:drugtime_mobile/features/reminder/presentation/widgets/lockscreen_privacy_gate.dart';

class MockKeyguardPlatform implements KeyguardPlatform {
  bool isLocked = false;
  int isKeyguardLockedCallCount = 0;
  int requestDismissKeyguardCallCount = 0;
  bool dismissResult = true;

  @override
  Future<bool> isKeyguardLocked() async {
    isKeyguardLockedCallCount++;
    return isLocked;
  }

  @override
  Future<bool> requestDismissKeyguard() async {
    requestDismissKeyguardCallCount++;
    if (dismissResult) {
      isLocked = false;
    }
    return dismissResult;
  }
}

void main() {
  group('LockscreenPrivacyGate (AC6, NT-02)', () {
    testWidgets('renders child directly when device is unlocked',
        (tester) async {
      final mockPlatform = MockKeyguardPlatform()..isLocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LockscreenPrivacyGate(
            platform: mockPlatform,
            child: const Text('Paracetamol 500mg - Sáng 1 viên'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paracetamol 500mg - Sáng 1 viên'), findsOneWidget);
      expect(find.text('Đến giờ uống thuốc'), findsNothing);
      expect(find.byKey(const Key('lockscreen_unlock_button')), findsNothing);
    });

    testWidgets(
        'shows Privacy Mask and hides child/medication details when device is locked',
        (tester) async {
      final mockPlatform = MockKeyguardPlatform()..isLocked = true;

      await tester.pumpWidget(
        MaterialApp(
          home: LockscreenPrivacyGate(
            platform: mockPlatform,
            child: const Text('Paracetamol 500mg - Sáng 1 viên'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Privacy mask NT-02
      expect(find.text('Đến giờ uống thuốc'), findsOneWidget);
      expect(find.text('Paracetamol 500mg - Sáng 1 viên'), findsNothing);
      expect(find.byKey(const Key('lockscreen_unlock_button')), findsOneWidget);
    });

    testWidgets(
        'tapping unlock button calls requestDismissKeyguard and reveals child upon success',
        (tester) async {
      final mockPlatform = MockKeyguardPlatform()
        ..isLocked = true
        ..dismissResult = true;

      await tester.pumpWidget(
        MaterialApp(
          home: LockscreenPrivacyGate(
            platform: mockPlatform,
            child: const Text('Paracetamol 500mg - Sáng 1 viên'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đến giờ uống thuốc'), findsOneWidget);
      expect(find.text('Paracetamol 500mg - Sáng 1 viên'), findsNothing);

      // Tap unlock button
      await tester.tap(find.byKey(const Key('lockscreen_unlock_button')));
      await tester.pumpAndSettle();

      expect(mockPlatform.requestDismissKeyguardCallCount, 1);
      // Device unlocked -> child revealed
      expect(find.text('Paracetamol 500mg - Sáng 1 viên'), findsOneWidget);
      expect(find.text('Đến giờ uống thuốc'), findsNothing);
    });

    testWidgets(
        're-checks lock status when application resumes from background',
        (tester) async {
      final mockPlatform = MockKeyguardPlatform()..isLocked = true;

      await tester.pumpWidget(
        MaterialApp(
          home: LockscreenPrivacyGate(
            platform: mockPlatform,
            child: const Text('Paracetamol 500mg - Sáng 1 viên'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đến giờ uống thuốc'), findsOneWidget);
      expect(find.text('Paracetamol 500mg - Sáng 1 viên'), findsNothing);

      // User unlocks device from outside, app is resumed
      mockPlatform.isLocked = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Paracetamol 500mg - Sáng 1 viên'), findsOneWidget);
      expect(find.text('Đến giờ uống thuốc'), findsNothing);
    });
  });
}
