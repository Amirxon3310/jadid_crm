import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_notice.dart';
import '../core/app_icon.dart';
import '../core/app_theme.dart';
import '../core/helpers.dart';
import '../core/user_avatar.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import '../data/optimistic_queue.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.store,
    required this.userId,
    this.onCancel,
  });
  final CrmStore store;
  final String userId;
  final VoidCallback? onCancel;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  final first = TextEditingController(),
      last = TextEditingController(),
      age = TextEditingController();
  final branch = TextEditingController(),
      phone = TextEditingController(),
      email = TextEditingController();
  String? gender;
  late AppRole role;
  late String outcome;
  bool picking = false, removeAvatar = false;
  int draftRevision = 0;
  final pendingDrafts = <int>{};
  Uint8List? avatarBytes;
  AppUser get user =>
      widget.store.users.firstWhere((u) => u.id == widget.userId);
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    first.text = user.displayFirstName;
    last.text = user.displayLastName;
    age.text = user.age?.toString() ?? '';
    branch.text = user.branch;
    phone.text = user.phone;
    email.text = user.contactEmail;
    gender = user.gender;
    role = user.role;
    outcome = user.studyStatus;
    avatarBytes = null;
    removeAvatar = false;
  }

  @override
  void dispose() {
    for (final c in [first, last, age, branch, phone, email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() => picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (file == null) return;
      if (await file.length() > 10 * 1024 * 1024)
        throw const FormatException('Rasm 10 MB dan kichik bo‘lsin.');
      final original = await file.readAsBytes();
      final png =
          original.length > 8 &&
          original[0] == 137 &&
          original[1] == 80 &&
          original[2] == 78 &&
          original[3] == 71;
      final jpg =
          original.length > 3 &&
          original[0] == 255 &&
          original[1] == 216 &&
          original[2] == 255;
      if (!png && !jpg)
        throw const FormatException('JPG yoki PNG rasm tanlang.');
      final codec = await ui.instantiateImageCodec(original);
      try {
        final frame = await codec.getNextFrame();
        try {
          if (frame.image.width > 1000 || frame.image.height > 1000)
            throw const FormatException(
              'Rasm o‘lchami 1000 × 1000 px dan oshmasin.',
            );
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null || data.lengthInBytes > 2 * 1024 * 1024)
            throw const FormatException('Rasm 2 MB dan kichik bo‘lsin.');
          if (mounted)
            setState(() {
              draftRevision++;
              avatarBytes = data.buffer.asUint8List();
              removeAvatar = false;
            });
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (error) {
      if (mounted)
        showAppNotice(
          context,
          error is FormatException ? error.message : 'Rasmni yuklab bo‘lmadi.',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate() || pendingDrafts.contains(draftRevision))
      return;
    final revision = draftRevision;
    pendingDrafts.add(revision);
    final store = widget.store;
    final edit = store.canEditProfile(user);
    final grade = store.canSetOutcome(user);
    final canRole = store.activeRole == AppRole.admin;
    try {
      final request = store.saveProfile(
        user,
        edit
            ? {
                'first_name': first.text.trim(),
                'last_name': last.text.trim(),
                'age': int.tryParse(age.text),
                'gender': gender,
                'branch': branch.text.trim(),
                'phone': phone.text.trim(),
                'contact_email': email.text.trim(),
              }
            : {},
        outcome: grade && role == AppRole.student ? outcome : null,
        role: canRole ? role : null,
        avatarBytes: avatarBytes,
        removeAvatar: removeAvatar,
      );
      setState(() {
        avatarBytes = null;
        removeAvatar = false;
      });
      await request;
      if (mounted) {
        showAppNotice(context, 'Profil saqlandi.');
      }
    } catch (error) {
      if (mounted && error is! MutationCancelled) {
        if (draftRevision == revision) setState(_reset);
        showAppNotice(
          context,
          'Profil saqlanmadi. Oldingi holat tiklandi.',
          isError: true,
        );
      }
    } finally {
      pendingDrafts.remove(revision);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.store.canEditProfile(user);
    final grade = widget.store.canSetOutcome(user);
    final admin = widget.store.activeRole == AppRole.admin;
    final enabled = edit && !picking && widget.store.profileFeaturesReady;
    final avatarEnabled =
        widget.store.canEditAvatar(user) &&
        !picking &&
        widget.store.profileFeaturesReady;
    final ready = widget.store.profileFeaturesReady;
    final fieldColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF293344)
        : const Color(0xFFF1F1F1);
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Surface(
          radius: 28,
          padding: 24,
          child: Form(
            key: form,
            onChanged: () => draftRevision++,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!ready)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text('Profil sozlamalari bazaga hali qo‘llanmagan.'),
                  ),
                Wrap(
                  spacing: 26,
                  runSpacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (avatarBytes != null)
                      CircleAvatar(
                        radius: 36,
                        backgroundImage: MemoryImage(avatarBytes!),
                      )
                    else if (removeAvatar)
                      CircleAvatar(
                        radius: 36,
                        child: Text(user.name.characters.firstOrNull ?? '?'),
                      )
                    else
                      UserAvatar(store: widget.store, user: user, radius: 36),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            FilledButton(
                              onPressed: avatarEnabled ? _pickAvatar : null,
                              child: Text(
                                picking ? 'Yuklanmoqda...' : 'Rasm yuklash',
                              ),
                            ),
                            TextButton.icon(
                              icon: Opacity(
                                opacity:
                                    avatarEnabled &&
                                        ready &&
                                        (avatarBytes != null ||
                                            user.avatarPath != null)
                                    ? 1
                                    : .4,
                                child: const AppIcon('delete', size: 16),
                              ),
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: AppColors.danger.withValues(
                                  alpha: .09,
                                ),
                                foregroundColor: AppColors.danger,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                              ),
                              onPressed:
                                  avatarEnabled &&
                                      ready &&
                                      (avatarBytes != null ||
                                          user.avatarPath != null)
                                  ? () => setState(() {
                                      draftRevision++;
                                      avatarBytes = null;
                                      removeAvatar = true;
                                    })
                                  : null,
                              label: const Text('Rasmni o‘chirish'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Kvadrat rasm, maksimum 1000 px va 2 MB.\nJPG yoki PNG.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, c) {
                    final columns = c.maxWidth >= 620 ? 2 : 1;
                    final fieldStyle = Theme.of(context).textTheme.bodyLarge!
                        .copyWith(
                          fontSize: 16,
                          height: 1.2,
                          letterSpacing: -.4,
                        );
                    final width = (c.maxWidth - (columns - 1) * 24) / columns;
                    Widget cell(String label, Widget child) => SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          child,
                        ],
                      ),
                    );
                    InputDecoration decoration(String hint) => InputDecoration(
                      hintText: hint,
                      fillColor: fieldColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    );
                    return Wrap(
                      spacing: 24,
                      runSpacing: 18,
                      children: [
                        cell(
                          'Ismingiz',
                          TextFormField(
                            style: fieldStyle,
                            controller: first,
                            enabled: enabled,
                            decoration: decoration('Ism'),
                            validator: (v) =>
                                edit && (v?.trim().isEmpty ?? true)
                                ? 'Ism kiriting'
                                : null,
                          ),
                        ),
                        cell(
                          'Familiyangiz',
                          TextFormField(
                            style: fieldStyle,
                            controller: last,
                            enabled: enabled,
                            decoration: decoration('Familiya'),
                          ),
                        ),
                        cell(
                          'Yoshingiz',
                          TextFormField(
                            style: fieldStyle,
                            controller: age,
                            enabled: enabled,
                            keyboardType: TextInputType.number,
                            decoration: decoration('Yosh'),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              final n = int.tryParse(v);
                              return n == null || n < 1 || n > 120
                                  ? '1–120 oralig‘ida kiriting'
                                  : null;
                            },
                          ),
                        ),
                        cell(
                          'Jinsingiz',
                          DropdownButtonFormField<String>(
                            style: fieldStyle,
                            key: ValueKey('gender-$gender'),
                            initialValue: gender,
                            decoration: decoration('Tanlang'),
                            items: const [
                              DropdownMenuItem(
                                value: 'male',
                                child: Text('Erkak'),
                              ),
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('Ayol'),
                              ),
                            ],
                            onChanged: enabled
                                ? (v) => setState(() => gender = v)
                                : null,
                          ),
                        ),
                        cell(
                          'Filial',
                          DropdownButtonFormField<String>(
                            style: fieldStyle,
                            key: ValueKey('branch-${branch.text}'),
                            initialValue: branch.text,
                            isExpanded: true,
                            borderRadius: BorderRadius.circular(20),
                            menuMaxHeight: 300,
                            decoration: decoration('Filial'),
                            items:
                                [
                                      '',
                                      ...widget.store.branches,
                                      if (branch.text.isNotEmpty &&
                                          !widget.store.branches.contains(
                                            branch.text,
                                          ))
                                        branch.text,
                                    ]
                                    .map(
                                      (name) => DropdownMenuItem(
                                        value: name,
                                        child: Text(
                                          name.isEmpty ? 'Tanlanmagan' : name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: enabled
                                ? (value) => setState(() {
                                    branch.text = value ?? '';
                                    draftRevision++;
                                  })
                                : null,
                          ),
                        ),
                        cell(
                          'Telefon raqamingiz',
                          TextFormField(
                            style: fieldStyle,
                            controller: phone,
                            enabled: enabled,
                            keyboardType: TextInputType.phone,
                            decoration: decoration('+998'),
                          ),
                        ),
                        cell(
                          'Email (ixtiyoriy)',
                          TextFormField(
                            style: fieldStyle,
                            controller: email,
                            enabled: enabled,
                            keyboardType: TextInputType.emailAddress,
                            decoration: decoration('Email'),
                            validator: (v) =>
                                v != null &&
                                    v.isNotEmpty &&
                                    !RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(v)
                                ? 'Email noto‘g‘ri'
                                : null,
                          ),
                        ),
                        cell(
                          'Rol',
                          DropdownButtonFormField<AppRole>(
                            style: fieldStyle,
                            key: ValueKey('role-$role'),
                            initialValue: role,
                            decoration: decoration('Rol'),
                            items: const [
                              DropdownMenuItem(
                                value: AppRole.admin,
                                child: Text('Admin'),
                              ),
                              DropdownMenuItem(
                                value: AppRole.teacher,
                                child: Text('Ustoz'),
                              ),
                              DropdownMenuItem(
                                value: AppRole.student,
                                child: Text('O‘quvchi'),
                              ),
                            ],
                            onChanged: admin && ready
                                ? (v) => setState(() => role = v!)
                                : null,
                          ),
                        ),
                        if (user.role == AppRole.student &&
                            role == AppRole.student)
                          cell(
                            'O‘qish holati',
                            DropdownButtonFormField<String>(
                              style: fieldStyle,
                              key: ValueKey('outcome-$outcome'),
                              initialValue: outcome,
                              isExpanded: true,
                              decoration: decoration('Holat'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'studying',
                                  child: Text('O‘qiyapti'),
                                ),
                                DropdownMenuItem(
                                  value: 'graduated',
                                  child: Text('Muvaffaqiyatli bitirgan'),
                                ),
                                DropdownMenuItem(
                                  value: 'unsuccessful',
                                  child: Text(
                                    'Muvaffaqiyatsiz yakunlagan',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              onChanged: grade && ready
                                  ? (v) => setState(() => outcome = v!)
                                  : null,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (user.role == AppRole.student) ...[
                  const SizedBox(height: 26),
                  const Text(
                    'Guruhlari',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    admin
                        ? 'Har bir guruhdagi holatini shu yerdan o‘zgartirasiz.'
                        : 'Holatni faqat admin o‘zgartiradi.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final enrolment in widget.store.students.where(
                    (s) => s.id == user.id,
                  ))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.store.groups
                                      .where((g) => g.id == enrolment.groupId)
                                      .firstOrNull
                                      ?.name ??
                                  'Guruh',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (admin && ready)
                            SizedBox(
                              width: 210,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'enrolment-${enrolment.groupId}-'
                                  '${enrolment.status}',
                                ),
                                initialValue: enrolment.status,
                                isExpanded: true,
                                borderRadius: BorderRadius.circular(16),
                                decoration: InputDecoration(
                                  fillColor: fieldColor,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                ),
                                items: [
                                  for (final option in enrollmentStatuses)
                                    DropdownMenuItem(
                                      value: option.value,
                                      child: Text(option.label),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value == null ||
                                      value == enrolment.status)
                                    return;
                                  runCrmAction(
                                    context,
                                    () => widget.store.setEnrollmentStatus(
                                      user.id,
                                      enrolment.groupId,
                                      value,
                                    ),
                                    success: 'Holat saqlandi',
                                  );
                                },
                              ),
                            )
                          else
                            StatusTag(enrolment.statusLabel, enrolment.status),
                        ],
                      ),
                    ),
                  if (widget.store.students.every((s) => s.id != user.id))
                    const Text(
                      'Guruhga biriktirilmagan',
                      style: TextStyle(color: AppColors.muted),
                    ),
                ],
                const SizedBox(height: 26),
                Wrap(
                  spacing: 18,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed:
                          ready &&
                              !picking &&
                              (edit ||
                                  grade ||
                                  (avatarEnabled &&
                                      (avatarBytes != null || removeAvatar)))
                          ? _save
                          : null,
                      child: const Text(
                        'O‘zgarishlarni saqlash',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        draftRevision++;
                        setState(_reset);
                        widget.onCancel?.call();
                      },
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: fieldColor,
                        foregroundColor: AppColors.muted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 18,
                        ),
                      ),
                      child: const Text('Bekor qilish'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void openProfile(BuildContext context, CrmStore store, String userId) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: AnimatedBuilder(
          animation: store,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ProfilePage(store: store, userId: userId),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> showProfiles(
  BuildContext context,
  CrmStore store, {
  ValueChanged<String>? onSelected,
}) async {
  var query = '';
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final users = store.users
            .where((u) => u.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return AlertDialog(
          title: const Text('Foydalanuvchilar'),
          content: SizedBox(
            width: 480,
            height: 420,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Ism bo‘yicha qidirish',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setDialogState(() => query = value),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: UserAvatar(
                          store: store,
                          user: user,
                          radius: 20,
                        ),
                        title: Text(user.name),
                        subtitle: Text(switch (user.role) {
                          AppRole.admin => 'Admin',
                          AppRole.teacher => 'Ustoz',
                          AppRole.student => 'O‘quvchi',
                        }),
                        trailing: const AppIcon('edit', size: 20),
                        onTap: () => Navigator.pop(context, user.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Yopish'),
            ),
          ],
        );
      },
    ),
  );
  if (selected != null && context.mounted) {
    if (onSelected != null) {
      onSelected(selected);
    } else {
      openProfile(context, store, selected);
    }
  }
}
