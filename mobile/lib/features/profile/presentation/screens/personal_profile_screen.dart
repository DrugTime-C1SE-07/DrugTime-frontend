import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/health_profile.dart';
import '../state/profile_controller.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_form_fields.dart';
import '../widgets/profile_icons.dart';
import '../widgets/profile_notices.dart';

class PersonalProfileScreen extends StatefulWidget {
  const PersonalProfileScreen({super.key});
  @override
  State<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
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
    if (_formGeneration != c.generation) {
      _formGeneration = c.generation;
      _formKey = GlobalKey<_PersonalFormState>();
    }
    return Scaffold(
      appBar: AppBar(
          title: const Text('Thông tin cá nhân'),
          leading: IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
              icon: const ProfileIcon('p-arrow-left'))),
      body: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, AppSpacing.xl),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ProfileNotices(hideSuccessNotice: true),
                    if (c.profile == null && c.loading) const ProfileLoading(),
                    if (c.profile != null && !c.denied)
                      _PersonalForm(key: _formKey, profile: c.profile!),
                  ]))),
      bottomNavigationBar: c.profile != null && !c.denied
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                    key: const Key('save-profile'),
                    onPressed: c.saving || c.loading ? null : _saveProfile,
                    child: Text(c.saving ? 'Đang lưu…' : 'Lưu thay đổi')),
              ),
            )
          : null,
    );
  }

  Future<void> _saveProfile() async {
    final saved = await _formKey?.currentState?._save() ?? false;
    if (!mounted || !saved) return;

    final c = ProfileScope.read(context);
    if (c.error != null || c.notice != 'Đã lưu thay đổi') return;

    final messenger = ScaffoldMessenger.of(context);
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
  final _email = TextEditingController();
  late DateTime? _dob = widget.profile.dateOfBirth;
  late String? _gender = widget.profile.gender;
  bool _dirty = false;
  @override
  void didUpdateWidget(_PersonalForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty) {
      _name.text = widget.profile.fullName ?? '';
      _dob = widget.profile.dateOfBirth;
      _gender = widget.profile.gender;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
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
        fullName: _name.text, dateOfBirth: _dob!, gender: _gender!));
    if (mounted && saved) setState(() => _dirty = false);
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    final c = ProfileScope.of(context);
    return Form(
        key: _formKey,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
              child: InkWell(
                  onTap: () => showAvatarPicker(context),
                  borderRadius: BorderRadius.circular(60),
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Stack(children: [
                        const ProfileAvatar(),
                        Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: AppColors.border)),
                                child: const Center(
                                    child: ProfileIcon('p-camera')))),
                      ])))),
          Center(
              child: TextButton(
                  onPressed: () => showAvatarPicker(context),
                  child: const Text('Đổi ảnh đại diện'))),
          const SizedBox(height: AppSpacing.lg),
          ProfileField(
              label: 'Họ và tên',
              child: TextFormField(
                  key: const Key('profile-name'),
                  controller: _name,
                  enabled: !c.saving,
                  onChanged: (_) => _dirty = true,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => ProfileDraft.validateName(v ?? ''),
                  decoration: const InputDecoration(
                      hintText: 'Nhập họ và tên',
                      suffixIcon: Center(
                          widthFactor: 1, child: ProfileIcon('p-pencil'))))),
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
                          decoration: InputDecoration(
                              errorText: field.errorText,
                              suffixIcon: const Center(
                                  widthFactor: 1,
                                  child: ProfileIcon('p-pencil'))),
                          child: Text(_dob == null
                              ? 'Chọn ngày sinh'
                              : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}'))),
                )),
            ProfileField(
                label: 'Giới tính',
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  isExpanded: true,
                  icon: const ProfileIcon('p-chevron-down'),
                  hint: const Text('Chọn giới tính'),
                  items: const [
                    DropdownMenuItem(value: 'nam', child: Text('Nam')),
                    DropdownMenuItem(value: 'nu', child: Text('Nữ')),
                    DropdownMenuItem(value: 'khac', child: Text('Khác'))
                  ],
                  validator: (v) =>
                      v == null ? 'Vui lòng chọn giới tính' : null,
                  onChanged: c.saving
                      ? null
                      : (v) => setState(() {
                            _gender = v;
                            _dirty = true;
                          }),
                )),
          ]),
          ProfileField(
              label: 'Email',
              child: TextFormField(
                  key: const Key('profile-email'),
                  controller: _email,
                  enabled: !c.saving,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (v) => ProfileDraft.validateEmail(v ?? ''),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      hintText: 'Nhập email',
                      helperText: _email.text.trim().isEmpty
                          ? null
                          : 'Email chưa được đồng bộ với máy chủ.',
                      suffixIcon: const Center(
                          widthFactor: 1, child: ProfileIcon('p-pencil'))))),
          const SizedBox(height: AppSpacing.xl),
        ]));
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Email không đúng định dạng';
    }
    return null;
  }
}
