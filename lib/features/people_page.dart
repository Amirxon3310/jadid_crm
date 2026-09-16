import 'dart:math';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../core/app_notice.dart';
import '../core/migration.dart';
import '../core/migration_setup.dart';
import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../core/helpers.dart';
import '../data/auth_service.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import '../core/user_avatar.dart';
import 'profile_page.dart';

class PeoplePage extends StatelessWidget {
  const PeoplePage({
    super.key,
    required this.store,
    required this.showTeachers,
    this.onOpenProfile,
  });

  final CrmStore store;
  final bool showTeachers;
  final ValueChanged<String>? onOpenProfile;
  void _open(BuildContext context, String id) {
    if (onOpenProfile != null) {
      onOpenProfile!(id);
      return;
    }
    openProfile(context, store, id);
  }

  @override
  Widget build(BuildContext context) {
    if (showTeachers) return _teachers(context);
    return _students(context);
  }

  Widget _teachers(BuildContext context) {
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _responsiveHeader(
            title: 'Ustozlar ro‘yxati',
            button: store.activeRole == AppRole.admin
                ? FilledButton.icon(
                    onPressed: () => store.isOnline
                        ? _addAccount(context, store, role: AppRole.teacher)
                        : _addTeacher(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Ustoz qo‘shish'),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          for (final teacher in store.teachers)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              onTap: () => _open(context, teacher.id),
              leading: UserAvatar(store: store, user: teacher),
              trailing: store.isOnline && store.activeRole == AppRole.admin
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'profile') _open(context, teacher.id);
                        if (value == 'delete')
                          _deleteMember(context, store, teacher);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              AppIcon('edit', size: 20),
                              SizedBox(width: 10),
                              Text('Profilni tahrirlash'),
                            ],
                          ),
                        ),
                        _deleteItem(),
                      ],
                    )
                  : const AppIcon('edit', size: 21),
              title: Text(
                teacher.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${store.groups.where((group) => group.teacherId == teacher.id).length} ta guruh',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addTeacher(BuildContext context) async {
    final name = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yangi ustoz'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Ism va familiya'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (saved == true) store.addTeacher(name.text.trim());
    name.dispose();
  }

  Widget _students(BuildContext context) {
    final visibleIds = store.visibleGroups.map((group) => group.id).toSet();
    final studentUserIds = store.users
        .where((user) => user.role == AppRole.student)
        .map((user) => user.id)
        .toSet();
    final students = store.students.where((student) {
      return studentUserIds.contains(student.id) &&
          (store.activeRole == AppRole.admin ||
              visibleIds.contains(student.groupId));
    }).toList();

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _responsiveHeader(
            title: 'O‘quvchilar ro‘yxati',
            button: store.activeRole == AppRole.admin
                ? FilledButton.icon(
                    onPressed: () => store.isOnline
                        ? _addAccount(context, store, role: AppRole.student)
                        : _addStudent(context),
                    icon: const Icon(Icons.add),
                    label: const Text('O‘quvchi qo‘shish'),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          for (final student in students)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              onTap: () => _open(context, student.id),
              leading: UserAvatar(
                store: store,
                user: store.users.firstWhere((u) => u.id == student.id),
              ),
              title: Text(
                student.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${student.groupId.isEmpty ? 'Guruh biriktirilmagan' : store.groupById(student.groupId).name}${student.phone.isEmpty ? '' : ' • ${student.phone}'}',
              ),
              trailing: store.isOnline && store.activeRole == AppRole.admin
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'profile') _open(context, student.id);
                        if (value == 'group') _assignGroup(context, student);
                        if (value == 'teacher')
                          runCrmAction(
                            context,
                            () => store.setRole(student.id, AppRole.teacher),
                          );
                        if (value == 'delete')
                          _deleteMember(
                            context,
                            store,
                            store.users.firstWhere((u) => u.id == student.id),
                          );
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              AppIcon('edit', size: 20),
                              SizedBox(width: 10),
                              Text('Profilni tahrirlash'),
                            ],
                          ),
                        ),
                        if (store.groups.isNotEmpty)
                          const PopupMenuItem(
                            value: 'group',
                            child: Text('Guruhga biriktirish'),
                          ),
                        const PopupMenuItem(
                          value: 'teacher',
                          child: Text('Ustoz rolini berish'),
                        ),
                        _deleteItem(),
                      ],
                    )
                  : const AppIcon('edit', size: 21),
            ),
        ],
      ),
    );
  }

  Future<void> _addStudent(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    String groupId = store.groups.first.id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Yangi o‘quvchi'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Ism va familiya',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: groupId,
                    decoration: const InputDecoration(labelText: 'Guruh'),
                    items: store.groups
                        .map(
                          (group) => DropdownMenuItem(
                            value: group.id,
                            child: Text(group.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => groupId = value ?? groupId),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Bekor qilish'),
              ),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Saqlash'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true)
      store.addStudent(name.text.trim(), phone.text.trim(), groupId);
    name.dispose();
    phone.dispose();
  }

  Future<void> _assignGroup(BuildContext context, Student student) async {
    String groupId = student.groupId.isEmpty
        ? store.groups.first.id
        : student.groupId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('${student.name} uchun guruh'),
            content: SizedBox(
              width: 420,
              child: DropdownButtonFormField<String>(
                initialValue: groupId,
                decoration: const InputDecoration(labelText: 'Guruh'),
                items: store.groups
                    .map(
                      (group) => DropdownMenuItem(
                        value: group.id,
                        child: Text(group.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => groupId = value ?? groupId),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Bekor qilish'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Biriktirish'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true && context.mounted)
      await runCrmAction(
        context,
        () => store.assignStudent(student.id, groupId),
      );
  }
}

Widget _responsiveHeader({required String title, Widget? button}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final titleWidget = Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      );
      if (button == null) return titleWidget;
      if (constraints.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [titleWidget, const SizedBox(height: 10), button],
        );
      }
      return Row(
        children: [
          Expanded(child: titleWidget),
          button,
        ],
      );
    },
  );
}

String _sixDigits() => '${100000 + Random().nextInt(900000)}';

/// Opens a pupil's or a teacher's account: the login and password start as
/// six-figure suggestions the admin can accept or type over. Six, because
/// Supabase refuses a password shorter than that.
Future<void> _addAccount(
  BuildContext context,
  CrmStore store, {
  required AppRole role,
}) async {
  final teacher = role == AppRole.teacher;
  final name = TextEditingController();
  final login = TextEditingController(text: _sixDigits());
  final password = TextEditingController(text: _sixDigits());
  final form = GlobalKey<FormState>();
  final entered =
      await showFormDialog<({String name, String login, String password})>(
        context: context,
        onDisposed: () {
          name.dispose();
          login.dispose();
          password.dispose();
        },
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text(teacher ? 'Yangi ustoz' : 'Yangi o‘quvchi'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Ism va familiya',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ism va familiyani kiriting'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: login,
                      decoration: InputDecoration(
                        labelText: 'Login',
                        suffixIcon: IconButton(
                          tooltip: 'Boshqa raqam',
                          onPressed: () =>
                              update(() => login.text = _sixDigits()),
                          icon: const Icon(Icons.casino_outlined, size: 20),
                        ),
                      ),
                      validator: (v) => AuthService.validateLogin(v ?? ''),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: password,
                      decoration: InputDecoration(
                        labelText: 'Parol',
                        suffixIcon: IconButton(
                          tooltip: 'Boshqa raqam',
                          onPressed: () =>
                              update(() => password.text = _sixDigits()),
                          icon: const Icon(Icons.casino_outlined, size: 20),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Parolni kiriting'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Login va parol taklif qilindi — xohlasangiz '
                      'o‘zingiznikini yozing. '
                      '${teacher ? 'Ustoz' : 'O‘quvchi'} shu login va parol '
                      'bilan kiradi.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Bekor qilish'),
              ),
              FilledButton(
                // Stays open on invalid input so the message is visible.
                onPressed: () {
                  if (form.currentState!.validate()) {
                    // Read while the controllers are still alive: the dialog
                    // disposes them as it closes.
                    Navigator.pop(dialogContext, (
                      name: name.text.trim(),
                      login: login.text.trim(),
                      password: password.text.trim(),
                    ));
                  }
                },
                child: const Text('Yaratish'),
              ),
            ],
          ),
        ),
      );
  // Saved from the page's own context, which outlives the dialog.
  if (entered == null || !context.mounted) return;
  await _saveAccount(
    context,
    store,
    role: role,
    name: entered.name,
    login: entered.login,
    password: entered.password,
  );
}

Future<void> _saveAccount(
  BuildContext context,
  CrmStore store, {
  required AppRole role,
  required String name,
  required String login,
  required String password,
}) async {
  try {
    await store.createAccount(
      name: name,
      login: login,
      password: password,
      role: role,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.rewardGreen),
        title: const Text('Akkaunt yaratildi'),
        content: SizedBox(
          width: 380,
          child: Text(
            '$name uchun:\n\nLogin: $login\nParol: $password\n\n'
            'Shu ma’lumotlarni '
            '${role == AppRole.teacher ? 'ustozga' : 'o‘quvchiga'} bering. '
            'Qolgan ma’lumotlarini profilidan to‘ldirasiz.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  } catch (error) {
    // The server's own words matter here: a password the project deems too
    // short has to say so, not turn into a generic failure.
    if (context.mounted) {
      showAppNotice(context, _accountError(error), isError: true);
    }
  }
}

String _accountError(Object error) => switch (error) {
  ArgumentError(:final message) => '$message',
  // Supabase answers in English; the two an admin actually runs into are
  // worth saying in Uzbek, with the way out.
  AuthException(:final message) when _saysShortPassword(message) =>
    'Parol juda qisqa. Supabase’da eng kam uzunlik belgilangan — uzunroq '
        'parol yozing yoki Authentication → Sign In / Providers bo‘limidan '
        'eng kam uzunlikni kamaytiring.',
  AuthException(:final message) when _saysTaken(message) =>
    'Bu login band. Boshqa login tanlang.',
  AuthException(:final message) => message,
  _ => 'Akkaunt yaratilmadi. Login band bo‘lishi mumkin.',
};

bool _saysShortPassword(String message) {
  final text = message.toLowerCase();
  return text.contains('password') &&
      (text.contains('at least') || text.contains('should be'));
}

bool _saysTaken(String message) {
  final text = message.toLowerCase();
  return text.contains('already registered') || text.contains('already exists');
}

PopupMenuItem<String> _deleteItem() => const PopupMenuItem(
  value: 'delete',
  child: Row(
    children: [
      Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
      SizedBox(width: 10),
      Text('O‘chirish', style: TextStyle(color: AppColors.danger)),
    ],
  ),
);

/// Removes a person from the centre, after naming exactly what goes with
/// them — this cannot be undone from the app.
Future<void> _deleteMember(
  BuildContext context,
  CrmStore store,
  AppUser user,
) async {
  final teacher = user.role == AppRole.teacher;
  final groups = store.groups.where((g) => g.teacherId == user.id).length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
      title: Text('${user.name}ni o‘chirasizmi?'),
      content: SizedBox(
        width: 420,
        child: Text(
          teacher
              ? 'Ustoz ro‘yxatdan butunlay o‘chadi.'
                    '${groups == 0 ? '' : ' $groups ta guruh ustozsiz qoladi — '
                              'keyin boshqa ustoz biriktirasiz.'}'
                    ' U belgilagan davomat va bergan vazifalar guruhda qoladi.'
              : 'O‘quvchi ro‘yxatdan butunlay o‘chadi. Davomati, uy vazifalari, '
                    'ballari va to‘lovlari ham o‘chadi.\n\nBu amalni '
                    'qaytarib bo‘lmaydi.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('O‘chirish'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await store.deleteMember(user.id);
    if (context.mounted) showAppNotice(context, '${user.name} o‘chirildi');
  } on MigrationMissing catch (missing) {
    if (context.mounted) await showMigrationSetup(context, missing);
  } catch (error) {
    if (context.mounted) {
      showAppNotice(context, crmActionError(error), isError: true);
    }
  }
}
