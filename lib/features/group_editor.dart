import 'package:flutter/material.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../data/models.dart';

Future<void> editStudyGroup(
  BuildContext context,
  CrmStore store, {
  StudyGroup? group,
}) async {
  if (store.activeRole != AppRole.admin) return;
  final name = TextEditingController(text: group?.name);
  final course = TextEditingController(text: group?.course);
  final schedule = TextEditingController(text: group?.schedule);
  final room = TextEditingController(text: group?.room);
  String teacherId = group?.teacherId ?? '';
  String status = group?.status ?? 'active';
  final days = <int>{...?group?.weekDays};
  final form = GlobalKey<FormState>();
  final staff = store.users
      .where((u) => u.role == AppRole.teacher || u.id == teacherId)
      .toList();
  final saved = await showFormDialog<bool>(
    context: context,
    onDisposed: () {
      name.dispose();
      course.dispose();
      schedule.dispose();
      room.dispose();
    },
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(group == null ? 'Yangi guruh' : 'Guruhni tahrirlash'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Guruh nomi'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Guruh nomini kiriting'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: course,
                    decoration: const InputDecoration(labelText: 'Kurs'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Kurs nomini kiriting'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: teacherId,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(20),
                    decoration: const InputDecoration(labelText: 'Ustoz'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Hozircha biriktirilmagan'),
                      ),
                      ...staff.map(
                        (u) =>
                            DropdownMenuItem(value: u.id, child: Text(u.name)),
                      ),
                    ],
                    onChanged: (v) => update(() => teacherId = v ?? ''),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    borderRadius: BorderRadius.circular(20),
                    decoration: const InputDecoration(
                      labelText: 'Guruh holati',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Faol')),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Tugatilgan'),
                      ),
                      DropdownMenuItem(
                        value: 'frozen',
                        child: Text('Muzlatilgan'),
                      ),
                    ],
                    onChanged: (v) => update(() => status = v ?? status),
                  ),
                  const SizedBox(height: 18),
                  const Text('Dars kunlari'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(
                      7,
                      (i) => FilterChip(
                        label: Text(
                          ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'][i],
                        ),
                        selected: days.contains(i + 1),
                        onSelected: (selected) => update(() {
                          selected ? days.add(i + 1) : days.remove(i + 1);
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: schedule,
                    decoration: const InputDecoration(
                      labelText: 'Dars vaqti / jadval',
                      hintText: '15:00–16:30',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: room,
                    decoration: const InputDecoration(labelText: 'Xona'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    ),
  );
  if (saved != true || !context.mounted) return;
  final teacher = staff.where((u) => u.id == teacherId).firstOrNull;
  final weekDays = days.toList()..sort();
  final groupName = name.text.trim(),
      groupCourse = course.text.trim(),
      groupSchedule = schedule.text.trim(),
      groupRoom = room.text.trim();
  await runCrmAction(
    context,
    () => group == null
        ? store.addGroup(
            name: groupName,
            course: groupCourse,
            teacher: teacher,
            schedule: groupSchedule,
            room: groupRoom,
            weekDays: weekDays,
            status: status,
          )
        : store.updateGroup(
            group.copyWith(
              name: groupName,
              course: groupCourse,
              teacherId: teacher?.id ?? '',
              teacherMembershipId: teacher?.membershipId ?? '',
              teacherName: teacher?.name ?? 'Ustoz biriktirilmagan',
              schedule: groupSchedule,
              room: groupRoom,
              weekDays: weekDays,
              status: status,
            ),
          ),
  );
}
