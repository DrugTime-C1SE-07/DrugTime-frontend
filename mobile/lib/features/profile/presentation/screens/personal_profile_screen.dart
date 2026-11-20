import 'package:flutter/material.dart';
import '../../../../shared/widgets/profile_flow_widgets.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/health_profile.dart';
import '../state/profile_controller.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_form_fields.dart';
import '../widgets/profile_icons.dart';
import '../widgets/profile_notices.dart';

/// Bóng của nút hành động chính theo Figma S08-1.
const _primaryButtonShadows = [
  BoxShadow(
    color: Color.fromRGBO(1, 61, 57, 0.3),
    offset: Offset(0, 5),
    blurRadius: 9,
    spreadRadius: -2,
  ),
  BoxShadow(
    color: Color.fromRGBO(1, 61, 57, 0.15),
    offset: Offset(0, 1),
    blurRadius: 2,
  ),
];

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});
  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  GlobalKey<_PersonalFormState>? _formKey;
  int? _formGeneration;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ProfileScope.read(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    final mediaQuery = MediaQuery.of(context);
    final missingBottomInset =
        (mediaQuery.viewPadding.bottom - mediaQuery.padding.bottom)
            .clamp(0.0, mediaQuery.viewPadding.bottom)
            .toDouble();
    if (_formGeneration != c.generation) {
      _formGeneration = c.generation;
      _formKey = GlobalKey<_PersonalFormState>();
    }
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: ProfileFlowHeader('Thông tin cá nhân',
            titleScale: MediaQuery.textScalerOf(context).scale(18) / 18,
            backgroundColor: AppColors.canvas),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ProfileNotices(hideSuccessNotice: true),
                      if (c.profile == null && c.loading)
                        const ProfileLoading(),
                      if (c.profile != null && !c.denied)
                        _PersonalForm(key: _formKey, profile: c.profile!),
                    ]))),
        bottomNavigationBar: c.profile != null && !c.denied
            ? SafeArea(
                top: false,
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(20, 8, 20, 12 + missingBottomInset),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      boxShadow: _primaryButtonShadows,
                    ),
                    child: FilledButton(
                        key: const Key('save-profile'),
                        style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppSizes.fieldCompact),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.field),
                          ),
                        ),
                        onPressed: c.saving || c.loading ? null : _saveProfile,
                        child: Text(c.saving ? 'Đang lưu…' : 'Lưu thay đổi')),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _saveProfile() async {
    final saved = await _formKey?.currentState?._save() ?? false;
    if (!mounted || !saved) return;

    final c = ProfileScope.read(context);
    if (c.error != null || c.notice != 'Đã lưu thay đổi') return;

    final messenger = _messengerKey.currentState!;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('profile-save-success-snackbar'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.brandTint,
          elevation: 2,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.brand, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                c.notice!,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.brand,
                ),
              ),
            ),
          ]),
        ),
      );
  }
}

class _PersonalForm extends StatefulWidget {
  const _PersonalForm({super.key, required this.profile});
  final HealthProfile profile;
  @override
  State<_PersonalForm> createState() => _PersonalFormState();
}

class _PersonalFormState extends State<_PersonalForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName ?? '');
  late final _email = TextEditingController(text: widget.profile.email ?? '');
  late final _phone = TextEditingController(
      text: widget.profile.phone == null
          ? ''
          : profilePhoneLabel(widget.profile.phone));
  late DateTime? _dob = widget.profile.dateOfBirth;
  late String? _gender = widget.profile.gender;
  bool _dirty = false;
  @override
  void didUpdateWidget(_PersonalForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty) {
      _name.text = widget.profile.fullName ?? '';
      _email.text = widget.profile.email ?? '';
      _phone.text = widget.profile.phone == null
          ? ''
          : profilePhoneLabel(widget.profile.phone);
      _dob = widget.profile.dateOfBirth;
      _gender = widget.profile.gender;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDate(FormFieldState<DateTime> field) async {
    final today = ProfileDraft.todayInVietnam(DateTime.now());
    final selected = await showDatePicker(
        context: context,
        initialDate: _dob == null || _dob!.isAfter(today) ? today : _dob!,
        firstDate: DateTime(1800),
        lastDate: today);
    if (!mounted || selected == null) return;
    setState(() {
      _dob = selected;
      _dirty = true;
    });
    field.didChange(selected);
  }

  Future<bool> _save() async {
    if (!_formKey.currentState!.validate()) return false;
    final c = ProfileScope.read(context);
    final saved = await c.update(ProfileDraft(
      fullName: _name.text,
      dateOfBirth: _dob!,
      gender: _gender!,
      email: _email.text.trim().isEmpty
          ? null
          : _email.text.trim().toLowerCase(),
      phone: _phone.text,
    ));
    if (mounted && saved) setState(() => _dirty = false);
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    const suffixPencil = Center(widthFactor: 1, child: ProfileIcon('p-pencil'));
    return Form(
        key: _formKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ProfileFlowCard(
              color: AppColors.brandTint,
              padding: EdgeInsets.zero,
              child: _AvatarBlock(onTap: () => showAvatarPicker(context))),
          const SizedBox(height: 16),
          ProfileField(
              label: 'Họ và tên',
              child: TextFormField(
                  key: const Key('profile-name'),
                  controller: _name,
                  enabled: !c.saving,
                  style: profileFieldTextStyle,
                  onChanged: (_) => _dirty = true,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => ProfileDraft.validateName(v ?? ''),
                  decoration: profileFieldDecoration(
                      hintText: 'Nhập họ và tên', suffixIcon: suffixPencil))),
          ProfileFieldPair(children: [
            ProfileField(
                label: 'Ngày sinh',
                child: FormField<DateTime>(
                  key: ValueKey('dob-${_dob?.toIso8601String()}'),
                  initialValue: _dob,
                  validator: (_) =>
                      ProfileDraft.validateDate(_dob, DateTime.now()),
                  builder: (field) => InkWell(
                      onTap: c.saving ? null : () => _pickDate(field),
                      child: InputDecorator(
                          decoration: profileFieldDecoration(
                              errorText: field.errorText,
                              suffixIcon: suffixPencil),
                          child: Text(
                              _dob == null
                                  ? 'Chọn ngày sinh'
                                  : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                              style: profileFieldTextStyle))),
                )),
            ProfileField(
                label: 'Giới tính',
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  isExpanded: true,
                  style: profileFieldTextStyle.copyWith(
                      fontFamily:
                          Theme.of(context).textTheme.bodyMedium?.fontFamily),
                  icon: const ProfileIcon('p-chevron-down'),
                  hint: const Text('Chọn giới tính',
                      style: profileFieldTextStyle),
                  items: const [
                    DropdownMenuItem(
                        value: 'nam',
                        child: Text('Nam', style: profileFieldTextStyle)),
                    DropdownMenuItem(
                        value: 'nu',
                        child: Text('Nữ', style: profileFieldTextStyle)),
                    DropdownMenuItem(
                        value: 'khac',
                        child: Text('Khác', style: profileFieldTextStyle))
                  ],
                  validator: (v) =>
                      v == null ? 'Vui lòng chọn giới tính' : null,
                  onChanged: c.saving
                      ? null
                      : (v) => setState(() {
                            _gender = v;
                            _dirty = true;
                          }),
                  decoration: profileFieldDecoration(),
                )),
          ]),
          ProfileField(
              label: 'Số điện thoại',
              child: TextFormField(
                  key: const Key('profile-phone'),
                  controller: _phone,
                  enabled: !c.saving,
                  style: profileFieldTextStyle,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _dirty = true,
                  decoration: profileFieldDecoration(
                      hintText: 'Nhập số điện thoại', suffixIcon: suffixPencil))),
          ProfileField(
              label: 'Email',
              child: TextFormField(
                  key: const Key('profile-email'),
                  controller: _email,
                  enabled: !c.saving,
                  style: profileFieldTextStyle,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty &&
                        (widget.profile.email?.isNotEmpty ?? false)) {
                      return 'Vui lòng nhập email';
                    }
                    return ProfileDraft.validateEmail(value);
                  },
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: profileFieldDecoration(
                      hintText: 'Nhập email',
                      helperText: _email.text.trim().isEmpty
                          ? null
                          : 'Email này dùng để đăng nhập và nhận OTP lần sau.',
                      suffixIcon: suffixPencil))),
          const SizedBox(height: AppSpacing.xl),
        ]));
  }
}

/// Khối ảnh đại diện: avatar 84, badge camera 26 và link đổi ảnh (Figma S08-1).
class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(children: [
        Semantics(
            button: true,
            label: 'Đổi ảnh đại diện',
            child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: Stack(clipBehavior: Clip.none, children: [
                  const ProfileAvatar(size: 72),
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border)),
                          child: const Center(child: ProfileIcon('p-camera')))),
                ]))),
        TextButton(onPressed: onTap, child: const Text('Đổi ảnh đại diện')),
      ]);
}
