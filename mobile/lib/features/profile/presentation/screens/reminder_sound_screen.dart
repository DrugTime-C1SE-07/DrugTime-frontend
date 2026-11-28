import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/notification/notification_preferences.dart';
import '../../../../core/notification/reminder_sound.dart';
import '../../../../core/notification/reminder_sound_controller.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';
import '../../../medication/presentation/widgets/medication_form_fields.dart';

class ReminderSoundScreen extends StatefulWidget {
  const ReminderSoundScreen({super.key, this.draftVibrationEnabled});

  /// Trạng thái rung nháp truyền từ `NotificationPreferencesScreen` (`S08-4`).
  final bool? draftVibrationEnabled;

  @override
  State<ReminderSoundScreen> createState() => _ReminderSoundScreenState();
}

class _ReminderSoundScreenState extends State<ReminderSoundScreen> {
  ReminderSoundController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = ReminderSoundScope.maybeOf(context);
  }

  @override
  void dispose() {
    _controller?.stopPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // Kênh thông báo theo âm chỉ có trên Android; iOS giữ trạng thái chưa khả dụng (C-06).
    final available =
        controller != null && defaultTargetPlatform == TargetPlatform.android;
    final effectiveVibration = widget.draftVibrationEnabled ??
        NotificationPreferencesScope.maybeOf(context)?.reminders.vibrate ??
        true;
    return Scaffold(
      backgroundColor: profileFlowCanvas,
      appBar: ProfileFlowHeader('Âm thanh nhắc nhở',
          titleScale: MediaQuery.textScalerOf(context).scale(18) / 18),
      body: SafeArea(
          child: available
              ? _SoundSettings(controller, vibrationEnabled: effectiveVibration)
              : const _UnavailableSettings()),
    );
  }
}

class _SoundSettings extends StatelessWidget {
  const _SoundSettings(this.c, {required this.vibrationEnabled});
  final ReminderSoundController c;
  final bool vibrationEnabled;

  @override
  Widget build(BuildContext context) {
    final silentNoVibrate =
        c.selected.kind == ReminderSoundKind.silent && !vibrationEnabled;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
      if (!c.customSupported && c.error != null) ...[
        _errorBanner,
        const SizedBox(height: 12),
      ],
      if (c.fallbackNotice) ...[
        _Banner('Âm thanh bạn chọn không còn, đã chuyển về chuông mặc định',
            onClose: c.dismissFallbackNotice),
        const SizedBox(height: 12),
      ],
      if (silentNoVibrate) ...[
        const CautionNote(
          text:
              'Đang chọn âm Im lặng và tắt rung: thông báo nhắc thuốc sẽ không kêu và không rung.',
        ),
        const SizedBox(height: 12),
      ],
      ProfileFlowCard(
          padding: EdgeInsets.zero,
          child: ProfileFlowRow('Âm lượng nhắc nhở',
              icon: Icons.volume_up_outlined,
              onTap: c.openSoundSettings,
              trailing: const Icon(Icons.open_in_new,
                  size: 18, color: AppColors.inkMuted))),
      const Padding(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text('Âm lượng theo cài đặt âm thanh thông báo của máy.',
              style: AppTextStyles.caption)),
      const SizedBox(height: 20),
      ProfileFlowSection('Chọn âm thanh', children: [
        for (final sound in ReminderSounds.all) _SoundTile(c, sound),
      ]),
      if (c.customSupported) ...[
        const SizedBox(height: 20),
        ProfileFlowSection('Âm thanh của bạn', children: [
          for (final sound in c.customSounds)
            _SoundTile(c, sound,
                onDelete: () => _confirmDelete(context, sound)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Lỗi thêm file hiện sát nút thêm, nơi người dùng đang nhìn.
                  if (c.error != null) ...[
                    _errorBanner,
                    const SizedBox(height: 12),
                  ],
                  ProfileFlowButton(
                      label: '+ Thêm âm thanh từ máy',
                      onPressed:
                          c.canAdd && !c.busy ? c.addFromDevice : null),
                  const SizedBox(height: 8),
                  Text(
                      c.canAdd
                          ? 'MP3, M4A, AAC, OGG hoặc WAV, tối đa 10 MB, dài 1 giây–5 phút.'
                          : 'Đã đủ ${ReminderSoundController.maxCustom} âm thanh. Xóa một âm thanh để thêm mới.',
                      style: AppTextStyles.caption),
                ]),
          ),
        ]),
      ],
    ]);
  }

  Widget get _errorBanner =>
      _Banner(c.error!, onClose: c.clearError, danger: true);

  Future<void> _confirmDelete(BuildContext context, ReminderSound sound) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa âm thanh?'),
        content: Text('"${sound.label}" sẽ bị xóa khỏi máy.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) await c.delete(sound.id);
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile(this.c, this.sound, {this.onDelete});
  final ReminderSoundController c;
  final ReminderSound sound;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final selected = c.selectedId == sound.id;
    final playing = c.playingId == sound.id;
    return Material(
      color: selected ? AppColors.brandTint : Colors.transparent,
      child: InkWell(
        onTap: () => c.select(sound.id),
        borderRadius: BorderRadius.circular(16),
        child: Semantics(
          selected: selected,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
              child: Row(children: [
                sound.playsSound
                    ? IconButton(
                        key: ValueKey('preview-${sound.id}'),
                        tooltip: playing ? 'Dừng' : 'Nghe thử',
                        onPressed: () => c.togglePreview(sound),
                        icon: Icon(
                            playing
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            color: AppColors.brand))
                    : const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.vibration,
                            size: 20, color: AppColors.inkMuted)),
                const SizedBox(width: 4),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(sound.label,
                          style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: AppColors.ink)),
                      if (sound.subtitle != null)
                        Text(sound.subtitle!, style: AppTextStyles.caption),
                    ])),
                if (onDelete != null)
                  IconButton(
                      key: ValueKey('delete-${sound.id}'),
                      tooltip: 'Xóa',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.inkMuted)),
                const SizedBox(width: 4),
                Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: selected ? AppColors.brand : AppColors.inkDisabled),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message, {required this.onClose, this.danger = false});
  final String message;
  final VoidCallback onClose;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
            color: danger ? AppColors.dangerBg : AppColors.brandTint,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(danger ? Icons.error_outline : Icons.info_outline,
              size: 18, color: danger ? AppColors.danger : AppColors.brand),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTextStyles.caption)),
          IconButton(
              tooltip: 'Đóng',
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18)),
        ]),
      );
}

class _UnavailableSettings extends StatelessWidget {
  const _UnavailableSettings();
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
        const ProfileUnavailable(
            message: 'Chọn và nghe thử âm thanh chưa khả dụng.'),
        const SizedBox(height: 20),
        ProfileFlowSection('Chọn âm thanh', children: [
          for (final sound in ReminderSounds.all)
            ProfileFlowRow(sound.label,
                icon: Icons.play_circle_outline,
                subtitle: sound.subtitle,
                unavailable: true,
                trailing: const Icon(Icons.radio_button_unchecked,
                    size: 20, color: AppColors.inkDisabled)),
        ]),
      ]);
}
