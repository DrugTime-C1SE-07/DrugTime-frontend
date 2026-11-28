import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:drugtime_mobile/app/router.dart';
import 'package:drugtime_mobile/app/theme/app_theme.dart';
import 'package:drugtime_mobile/core/notification/notification_service.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_controller.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_native.dart';
import 'package:drugtime_mobile/core/notification/reminder_sound_store.dart';
import 'package:drugtime_mobile/features/profile/presentation/state/profile_controller.dart';

Widget profileApp(ProfileController c, Widget child,
        {double textScale = 1,
        EdgeInsets insets = EdgeInsets.zero,
        bool previewFont = false,
        ReminderSoundController? sound}) =>
    ReminderSoundScope(
      controller: sound ?? fakeReminderSoundController(),
      child: ProfileScope(
          controller: c,
          child: MaterialApp(
            theme: previewFont
                ? buildAppTheme().copyWith(
                    textTheme: buildAppTheme()
                        .textTheme
                        .apply(fontFamily: 'ProfilePreview'),
                    appBarTheme: buildAppTheme().appBarTheme.copyWith(
                        titleTextStyle: AppTextStyles.heading
                            .copyWith(fontFamily: 'ProfilePreview')),
                    filledButtonTheme: FilledButtonThemeData(
                        style: buildAppTheme()
                            .filledButtonTheme
                            .style!
                            .copyWith(
                                textStyle: WidgetStatePropertyAll(AppTextStyles
                                    .bodyStrong
                                    .copyWith(fontFamily: 'ProfilePreview')))),
                    textButtonTheme: TextButtonThemeData(
                        style: buildAppTheme().textButtonTheme.style!.copyWith(
                            textStyle: WidgetStatePropertyAll(AppTextStyles
                                .bodyStrong
                                .copyWith(fontFamily: 'ProfilePreview')))),
                  )
                : buildAppTheme(),
            locale: const Locale('vi'),
            supportedLocales: const [Locale('vi')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            onGenerateRoute: onGenerateRoute,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                    viewInsets: insets,
                    // The medic mascot idles forever; still it so pumpAndSettle can settle.
                    disableAnimations: true),
                child: child!),
            home: Scaffold(body: child),
          )),
    );

ReminderSoundController fakeReminderSoundController({
  FakeReminderSoundStore? store,
  FakeReminderSoundNative? native,
  FakeChannelPlatform? notifications,
  TargetPlatform? targetPlatform,
  bool Function()? vibrationEnabled,
}) =>
    ReminderSoundController(
      store: store ?? FakeReminderSoundStore(),
      native: native ?? FakeReminderSoundNative(),
      notifications: notifications ?? FakeChannelPlatform(),
      targetPlatform: targetPlatform,
      vibrationEnabled: vibrationEnabled,
      onLog: (_) {},
    );

class FakeReminderSoundStore implements ReminderSoundStore {
  FakeReminderSoundStore([this.settings = const ReminderSoundSettings()]);
  ReminderSoundSettings settings;
  int writes = 0;

  @override
  Future<ReminderSoundSettings> read() async => settings;

  @override
  Future<void> write(ReminderSoundSettings value) async {
    writes++;
    settings = value;
  }

  @override
  Future<void> clear() async => settings = const ReminderSoundSettings();
}

class FakeReminderSoundNative implements ReminderSoundNative {
  int sdk = 34;
  PickedAudio? picked;
  int? durationMs = 15000;
  Object? commitError;
  final missing = <String>{};
  final calls = <String>[];
  final committed = <({String id, String ext, int number})>[];
  void Function()? previewDone;

  @override
  set onPreviewDone(void Function()? callback) => previewDone = callback;

  @override
  Future<int> sdkInt() async => sdk;

  @override
  Future<PickedAudio?> pick() async {
    calls.add('pick');
    return picked;
  }

  @override
  Future<int?> probeDurationMs(String path) async => durationMs;

  @override
  Future<({String path, String uri})> commit(
      {required String tempPath,
      required String id,
      required String ext,
      required int number}) async {
    if (commitError != null) throw commitError!;
    committed.add((id: id, ext: ext, number: number));
    return (
      path: '/files/reminder_sounds/$id.$ext',
      uri: 'content://media/external/audio/media/$number'
    );
  }

  @override
  Future<void> discard(String tempPath) async => calls.add('discard');

  @override
  Future<void> delete({required String path, required String uri}) async =>
      calls.add('delete $path');

  @override
  Future<bool> exists({required String path, required String uri}) async =>
      !missing.contains(path);

  @override
  Future<void> play(ReminderSound sound) async => calls.add('play ${sound.id}');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> openSoundSettings() async => calls.add('openSoundSettings');
}

class FakeChannelPlatform extends NotificationPlatform {
  final created = <String>[];
  final deleted = <String>[];

  @override
  Future<void> createNotificationChannel(
          AndroidNotificationChannel channel) async =>
      created.add(channel.id);

  @override
  Future<void> deleteNotificationChannel(String channelId) async =>
      deleted.add(channelId);

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async =>
      true;

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {}

  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  Future<List<PendingNotificationRequest>>
      pendingNotificationRequests() async => [];
}
