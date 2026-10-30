import 'package:flutter/material.dart';
import '../core/preview/app_preview_scope.dart';
import '../features/adherence_history/domain/entities/adherence_demo_preset.dart';
import 'app.dart';
import 'app_shell.dart';
import 'app_preview_session.dart';

/// Uses the actual five-tab app with memory-only dependencies.
class AdherenceDemoApp extends StatefulWidget {
  const AdherenceDemoApp(
      {super.key, this.now, this.preset = AdherenceDemoPreset.mixed});
  final DateTime? now;
  final AdherenceDemoPreset preset;
  @override
  State<AdherenceDemoApp> createState() => _AdherenceDemoAppState();
}

class _AdherenceDemoAppState extends State<AdherenceDemoApp> {
  late AppPreviewSession _session = _create();
  int _epoch = 0;
  AppPreviewSession _create({bool authenticated = true}) => AppPreviewSession(
      now: widget.now,
      authenticated: authenticated,
      preset: widget.preset,
      onLogout: _loggedOut);
  void _loggedOut() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final previous = _session;
      setState(() {
        _session = _create(authenticated: false);
        _epoch++;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    });
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPreviewScope(
      clock: _session.clock,
      child: DrugTimeApp(
          key: ValueKey(_epoch),
          authController: _session.auth,
          initialTab: AppTab.reminders,
          preview: true,
          adherenceHistoryRepository: _session.history,
          medicationRepository: _session.medications,
          consentRepository: _session.consents,
          profileRepository: _session.profile,
          familyLinkRepository: _session.family,
          familyLinkCodeRepository: _session.codes,
          clock: () => _session.clock));
}
