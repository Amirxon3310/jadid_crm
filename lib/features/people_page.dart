import 'dart:math';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../core/app_notice.dart';
import '../core/migration.dart';
import '../core/migration_setup.dart';
import '../core/app_theme.dart';
import '../core/filter_bar.dart';
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

  Widget _students(BuildContext context) => _StudentsList(
    store: store,
    onOpen: (id) => _open(context, id),
    onAssignGroup: (student) => _assignGroup(context, student),
    onAddOffline: () => _addStudent(context),
  );

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

String _fourDigits() => '${1000 + Random().nextInt(9000)}';

/// A login the database will accept: a letter first, then three figures.
/// Still four characters to read out, but never starting with a digit.
String _suggestedLogin() {
  const letters = 'abdefghkmnprstuvxyz';
  final random = Random();
  return letters[random.nextInt(letters.length)] +
      '${100 + random.nextInt(900)}';
}

/// Opens a pupil's or a teacher's account: the login and password start as
/// four-figure suggestions the admin can accept or type over. Four is short
/// enough to read out and write down, which is how the centre hands them on.
Future<void> _addAccount(
  BuildContext context,
  CrmStore store, {
  required AppRole role,
}) async {
  final teacher = role == AppRole.teacher;
  final name = TextEditingController();
  final login = TextEditingController(text: _suggestedLogin());
  final password = TextEditingController(text: _fourDigits());
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
                              update(() => login.text = _suggestedLogin()),
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
                              update(() => password.text = _fourDigits()),
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
  // The database checks the login's shape; its own words are unreadable.
  ArgumentError(:final message)
      when '$message'.contains('username_format_check') =>
    'Login bazadagi qoidaga to‘g‘ri kelmadi. Harf bilan boshlanadigan, '
        'faqat kichik lotin harflari, raqam va _ belgisidan iborat login '
        'yozing (masalan: a821).',
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

/// The pupils, with a way to find one: by name, by whether they have a group,
/// and by whether they are still studying.
class _StudentsList extends StatefulWidget {
  const _StudentsList({
    required this.store,
    required this.onOpen,
    required this.onAssignGroup,
    required this.onAddOffline,
  });

  final CrmStore store;
  final ValueChanged<String> onOpen;
  final ValueChanged<Student> onAssignGroup;

  /// The demo dialog used when there is no server to open an account on.
  final VoidCallback onAddOffline;

  @override
  State<_StudentsList> createState() => _StudentsListState();
}

class _StudentsListState extends State<_StudentsList> {
  String query = '';

  /// null = every pupil, '' = those without a group, otherwise a group id.
  String? groupFilter;

  /// null = every pupil, true = studying, false = frozen, finished or gone.
  bool? activeFilter;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final visibleIds = store.visibleGroups.map((group) => group.id).toSet();
    final studentUserIds = store.users
        .where((user) => user.role == AppRole.student)
        .map((user) => user.id)
        .toSet();
    final all = store.students.where((student) {
      return studentUserIds.contains(student.id) &&
          (store.activeRole == AppRole.admin ||
              visibleIds.contains(student.groupId));
    }).toList();
    final groups = <String, String>{
      for (final student in all)
        if (student.groupId.isNotEmpty)
          student.groupId:
              store.groups
                  .where((g) => g.id == student.groupId)
                  .firstOrNull
                  ?.name ??
              'Guruh',
    };
    if (groupFilter != null &&
        groupFilter!.isNotEmpty &&
        !groups.containsKey(groupFilter)) {
      groupFilter = null;
    }
    final students =
        all.where((student) {
          final matchesName = student.name.toLowerCase().contains(
            query.trim().toLowerCase(),
          );
          final matchesGroup =
              groupFilter == null ||
              (groupFilter!.isEmpty
                  ? student.groupId.isEmpty
                  : student.groupId == groupFilter);
          final matchesState =
              activeFilter == null || student.active == activeFilter;
          return matchesName && matchesGroup && matchesState;
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _responsiveHeader(
            title: 'O‘quvchilar ro‘yxati (${students.length})',
            button: store.activeRole == AppRole.admin
                ? FilledButton.icon(
                    onPressed: () => store.isOnline
                        ? _addAccount(context, store, role: AppRole.student)
                        : widget.onAddOffline(),
                    icon: const Icon(Icons.add),
                    label: const Text('O‘quvchi qo‘shish'),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          FilterSearch(
            hint: 'Ism bo‘yicha qidirish',
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilterField<String?>(
                label: 'Guruh',
                icon: Icons.layers_outlined,
                active: groupFilter != null,
                value: groupFilter,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Barcha o‘quvchilar'),
                  ),
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Guruhga biriktirilmagan'),
                  ),
                  for (final entry in groups.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => groupFilter = value),
              ),
              FilterField<bool?>(
                label: 'Holat',
                icon: Icons.filter_alt_outlined,
                active: activeFilter != null,
                value: activeFilter,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Barcha holatlar')),
                  DropdownMenuItem(value: true, child: Text('Faol')),
                  DropdownMenuItem(value: false, child: Text('Faol emas')),
                ],
                onChanged: (value) => setState(() => activeFilter = value),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 26),
                child: ClearFiltersButton(
                  count: [
                    groupFilter != null,
                    activeFilter != null,
                    query.trim().isNotEmpty,
                  ].where((on) => on).length,
                  onPressed: () => setState(() {
                    groupFilter = null;
                    activeFilter = null;
                    query = '';
                  }),
                ),
              ),
            ],
          ),
          if (students.isEmpty)
            const EmptyState(
              text: 'O‘quvchi topilmadi',
              icon: Icons.person_search_outlined,
            ),
          for (final student in students)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              onTap: () => widget.onOpen(student.id),
              leading: UserAvatar(
                store: store,
                user: store.users.firstWhere((u) => u.id == student.id),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      student.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusTag(student.statusLabel, student.status),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text(
                      student.groupId.isEmpty
                          ? 'Guruh biriktirilmagan'
                          : groups[student.groupId] ?? 'Guruh',
                      style: TextStyle(
                        color: student.groupId.isEmpty
                            ? AppColors.penaltyRed
                            : AppColors.muted,
                      ),
                    ),
                    if (student.phone.isNotEmpty)
                      Text(
                        student.phone,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    Text(
                      '${store.pointsOf(student.id)} ball',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              trailing: store.isOnline && store.activeRole == AppRole.admin
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'profile') widget.onOpen(student.id);
                        if (value == 'group') widget.onAssignGroup(student);
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
}
