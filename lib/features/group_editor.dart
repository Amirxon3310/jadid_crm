import '../core/app_theme.dart';
import 'package:flutter/material.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../data/models.dart';

String _formatTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseTime(String value) {
  if (value.isEmpty) return null;
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

Future<void> editStudyGroup(
  BuildContext context,
  CrmStore store, {
  StudyGroup? group,
}) async {
  if (store.activeRole != AppRole.admin) return;
  final name = TextEditingController(text: group?.name);
  final course = TextEditingController(text: group?.course);
  final room = TextEditingController(text: group?.room);
  final totalLessons = TextEditingController(
    text: group?.totalLessons?.toString() ?? '',
  );
  DateTime? startsOn = group?.startsOn;
  String teacherId = group?.teacherId ?? '';
  String status = group?.status ?? 'active';
  String lessonStartTime = group?.lessonStartTime ?? '';
  String lessonEndTime = group?.lessonEndTime ?? '';
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
                  const SizedBox(height: 18),
                  const Text('Dars vaqti'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  _parseTime(lessonStartTime) ??
                                  const TimeOfDay(hour: 15, minute: 0),
                            );
                            if (picked == null) return;
                            update(
                              () => lessonStartTime = _formatTimeOfDay(picked),
                            );
                          },
                          child: Text(
                            lessonStartTime.isEmpty
                                ? 'Boshlanish vaqti'
                                : 'Boshlanish: $lessonStartTime',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  _parseTime(lessonEndTime) ??
                                  const TimeOfDay(hour: 16, minute: 30),
                            );
                            if (picked == null) return;
                            update(
                              () => lessonEndTime = _formatTimeOfDay(picked),
                            );
                          },
                          child: Text(
                            lessonEndTime.isEmpty
                                ? 'Tugash vaqti'
                                : 'Tugash: $lessonEndTime',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: room,
                    decoration: const InputDecoration(labelText: 'Xona'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: totalLessons,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Umumiy darslar soni',
                      helperText: 'Kurs necha darsdan iborat',
                    ),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      startsOn == null
                          ? 'Boshlanish sanasi'
                          : 'Boshlanish: ${shortDate(startsOn!)}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startsOn ?? now,
                        firstDate: DateTime(now.year - 3),
                        lastDate: DateTime(now.year + 3),
                      );
                      if (picked != null) update(() => startsOn = picked);
                    },
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
  final lessonCount = int.tryParse(totalLessons.text.trim());
  final groupName = name.text.trim(),
      groupCourse = course.text.trim(),
      groupRoom = room.text.trim(),
      groupSchedule = lessonStartTime.isEmpty || lessonEndTime.isEmpty
          ? ''
          : '$lessonStartTime–$lessonEndTime';
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
            lessonStartTime: lessonStartTime,
            lessonEndTime: lessonEndTime,
            totalLessons: lessonCount,
            startsOn: startsOn,
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
              lessonStartTime: lessonStartTime,
              lessonEndTime: lessonEndTime,
              totalLessons: lessonCount,
              startsOn: startsOn,
            ),
          ),
  );
}
