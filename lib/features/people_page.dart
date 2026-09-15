import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../core/helpers.dart';
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
    } else {
      openProfile(context, store, id);
    }
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
            button: store.isOnline
                ? null
                : FilledButton.icon(
                    onPressed: () => _addTeacher(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Ustoz qo‘shish'),
                  ),
          ),
          const SizedBox(height: 16),
          for (final teacher in store.teachers)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              onTap: () => _open(context, teacher.id),
              leading: UserAvatar(store: store, user: teacher),
              trailing: const AppIcon('edit', size: 21),
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
            button: store.activeRole == AppRole.admin && !store.isOnline
                ? FilledButton.icon(
                    onPressed: () => _addStudent(context),
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
