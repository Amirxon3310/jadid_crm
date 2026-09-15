import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import 'group_editor.dart';
import 'lesson_checkin_card.dart';

class GroupPage extends StatefulWidget {
  const GroupPage({
    super.key,
    required this.store,
    required this.group,
    this.startTab = 0,
  });

  final CrmStore store;
  final StudyGroup group;
  final int startTab;

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  late int tab;

  @override
  void initState() {
    super.initState();
    tab = widget.startTab;
    widget.store.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant GroupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_refresh);
      widget.store.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.store.visibleGroups
        .where((g) => g.id == widget.store.resolveId(widget.group.id))
        .firstOrNull;
    if (group == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Guruh')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Guruh saqlanmadi.'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Orqaga qaytish'),
              ),
            ],
          ),
        ),
      );
    const labels = [
      'Ma’lumot',
      'Jadval',
      'Davomat',
      'Uy vazifalari',
      'Jurnal',
      'Reyting',
    ];
    final pages = [
      _InfoTab(store: widget.store, group: group),
      _ScheduleTab(store: widget.store, group: group),
      _AttendanceTab(store: widget.store, group: group),
      _HomeworkTab(store: widget.store, group: group),
      _JournalTab(store: widget.store, group: group),
      _RankingTab(store: widget.store, group: group),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (widget.store.activeRole == AppRole.admin)
            IconButton(
              tooltip: 'Guruhni tahrirlash',
              icon: const AppIcon('edit', size: 22),
              onPressed: () =>
                  editStudyGroup(context, widget.store, group: group),
            ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '${group.teacherName} • ${group.statusLabel}',
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: List.generate(labels.length, (index) {
                    final selected = tab == index;
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 10,
                        bottom: 10,
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: selected
                              ? AppColors.primary
                              : AppColors.muted,
                          backgroundColor: selected
                              ? AppColors.softBlue
                              : Colors.transparent,
                        ),
                        onPressed: () => setState(() => tab = index),
                        child: Text(labels[index]),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: pages[tab],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final students = _visibleStudents(store, group.id);
    return Column(
      children: [
        Surface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 650;
              final details = [
                _Detail(
                  label: 'Guruh holati',
                  value: group.statusLabel,
                  icon: Icons.info_outline,
                ),
                _Detail(
                  label: 'Kurs',
                  value: group.course,
                  icon: Icons.school_outlined,
                ),
                _Detail(
                  label: 'Ustoz',
                  value: group.teacherName,
                  icon: Icons.person_outline,
                  asset: 'user',
                ),
                _Detail(
                  label: 'Jadval',
                  value: group.schedule,
                  icon: Icons.schedule_outlined,
                ),
                _Detail(
                  label: 'Xona',
                  value: group.room,
                  icon: Icons.meeting_room_outlined,
                ),
              ];
              if (narrow) return Column(children: details);
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: details
                    .map(
                      (item) => SizedBox(
                        width: (constraints.maxWidth - 20) / 2,
                        child: item,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O‘quvchilar (${students.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final student in students)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 3),
                  leading: CircleAvatar(
                    child: Text(student.name.substring(0, 1)),
                  ),
                  title: Text(student.name),
                  subtitle: Text(student.phone),
                  trailing: store.canManageGroup(group.id)
                      ? PopupMenuButton<String>(
                          tooltip: 'Guruhdagi o‘qish holati',
                          initialValue: student.status,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          onSelected: (value) => runCrmAction(
                            context,
                            () => store.setEnrollmentStatus(
                              student.id,
                              group.id,
                              value,
                            ),
                          ),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'active',
                              child: Text('Aktiv'),
                            ),
                            PopupMenuItem(
                              value: 'completed',
                              child: Text('Tugatgan'),
                            ),
                            PopupMenuItem(value: 'left', child: Text('Ketgan')),
                          ],
                          child: Chip(
                            label: Text(student.statusLabel),
                            avatar: const Icon(Icons.expand_more, size: 18),
                          ),
                        )
                      : Text(student.statusLabel),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    required this.icon,
    this.asset,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? asset;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.softBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AppIcon(asset, active: true, fallback: icon, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ],
  );
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final lessons = store.lessonsOf(group.id);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dars jadvali',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              if (store.canManageGroup(group.id) && group.active)
                FilledButton.icon(
                  onPressed: () => _addLesson(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Dars qo‘shish'),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(group.schedule, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 20),
          for (final lesson in lessons)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              leading: const CircleAvatar(
                backgroundColor: AppColors.softBlue,
                child: Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: Text(
                lesson.topic,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${shortDate(lesson.startsAt)} • ${shortTime(lesson.startsAt)}',
              ),
              trailing: PopupMenuButton<String>(
                enabled: store.canManageGroup(group.id),
                tooltip: 'Dars holati',
                initialValue: lesson.status,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onSelected: (value) => runCrmAction(
                  context,
                  () => store.setLessonStatus(lesson.id, value),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'planned', child: Text('Rejada')),
                  PopupMenuItem(value: 'completed', child: Text('O‘tilgan')),
                  PopupMenuItem(
                    value: 'cancelled',
                    child: Text('Bekor qilingan'),
                  ),
                ],
                child: Chip(
                  label: Text(switch (lesson.status) {
                    'completed' => 'O‘tilgan',
                    'cancelled' => 'Bekor qilingan',
                    _ => 'Rejada',
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addLesson(BuildContext context) async {
    final topic = TextEditingController();
    DateTime startsAt = DateTime.now();
    while (group.weekDays.isNotEmpty &&
        !group.weekDays.contains(tashkentDate(startsAt).weekday)) {
      startsAt = startsAt.add(const Duration(days: 1));
    }
    final saved = await showFormDialog<bool>(
      context: context,
      onDisposed: topic.dispose,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Yangi dars'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: topic,
                    decoration: const InputDecoration(
                      labelText: 'Dars mavzusi',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      '${shortDate(startsAt)} • ${shortTime(startsAt)}',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: startsAt,
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(startsAt),
                      );
                      if (time == null) return;
                      setDialogState(
                        () => startsAt = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    },
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
                onPressed: () => topic.text.trim().isEmpty
                    ? null
                    : Navigator.pop(context, true),
                child: const Text('Saqlash'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true && context.mounted)
      await runCrmAction(
        context,
        () => store.addLesson(group.id, topic.text.trim(), startsAt),
      );
  }
}

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  String? lessonId;
  Map<String, AttendanceStatus> values = {};

  @override
  Widget build(BuildContext context) {
    final lessons = widget.store.lessonsOf(widget.group.id);
    if (lessons.isEmpty)
      return const Surface(
        child: EmptyState(text: 'Darslar hali yaratilmagan'),
      );
    lessonId = widget.store.resolveId(
      lessonId ??
          (lessons.where((l) => widget.store.isCheckinDay(l)).firstOrNull ??
                  lessons.first)
              .id,
    );
    if (!lessons.any((lesson) => lesson.id == lessonId)) {
      lessonId = lessons.first.id;
      values.clear();
    }
    final lesson = lessons.firstWhere((item) => item.id == lessonId);
    final students = _visibleStudents(widget.store, widget.group.id);

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final picker = SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(lessonId),
                  initialValue: lessonId,
                  decoration: const InputDecoration(
                    labelText: 'Darsni tanlang',
                  ),
                  items: lessons.map((item) {
                    return DropdownMenuItem(
                      value: item.id,
                      child: Text(
                        '${shortDate(item.startsAt)} • ${item.topic}',
                      ),
                    );
                  }).toList(),
                  onChanged: (id) => setState(() {
                    lessonId = id;
                    values.clear();
                  }),
                ),
              );
              const title = Text(
                'Davomat',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              );
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), picker],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  picker,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (widget.store.activeRole != AppRole.student)
            LessonCheckinCard(store: widget.store, lesson: lesson),
          for (final student in students)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final selected =
                      values[student.id] ??
                      widget.store.attendance[lesson.id]?[student.id];
                  final choices = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AttendanceStatus.values.map((status) {
                      return ChoiceChip(
                        label: Text(_attendanceLabel(status)),
                        selected: selected == status,
                        onSelected:
                            !widget.store.canMarkLesson(lesson) ||
                                (!student.active &&
                                    widget.store.activeRole != AppRole.admin)
                            ? null
                            : (_) =>
                                  setState(() => values[student.id] = status),
                      );
                    }).toList(),
                  );
                  if (constraints.maxWidth < 650) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name),
                        const SizedBox(height: 8),
                        choices,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: Text(student.name)),
                      choices,
                    ],
                  );
                },
              ),
            ),
          if (widget.store.activeRole != AppRole.student)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: values.isEmpty || !widget.store.canMarkLesson(lesson)
                    ? null
                    : () {
                        final changes = Map<String, AttendanceStatus>.of(
                          values,
                        );
                        runCrmAction(
                          context,
                          () => widget.store.saveAttendance(lesson.id, changes),
                          success: 'Davomat saqlandi',
                        );
                        setState(() => values.clear());
                      },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Saqlash'),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeworkTab extends StatelessWidget {
  const _HomeworkTab({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final homeworks = store.homeworksOf(group.id);
    return Column(
      children: [
        Surface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const title = Text(
                'Uy vazifalari',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              );
              final button = FilledButton.icon(
                onPressed: () => _createHomework(context),
                icon: const Icon(Icons.add),
                label: const Text('Vazifa berish'),
              );
              if (!store.canManageGroup(group.id) || !group.active)
                return title;
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 10), button],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  button,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (homeworks.isEmpty)
          const Surface(child: EmptyState(text: 'Uy vazifasi berilmagan')),
        for (final homework in homeworks) ...[
          Surface(
            child: _HomeworkCard(
              store: store,
              group: group,
              homework: homework,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Future<void> _createHomework(BuildContext context) async {
    final choices = store
        .lessonsOf(group.id)
        .where((l) => l.status != 'cancelled')
        .toList();
    if (choices.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Avval dars qo‘shing'),
          content: const Text(
            'Uy vazifasi darsga bog‘lanadi. Jadval bo‘limida dars mavzusini kiriting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Yopish'),
            ),
          ],
        ),
      );
      return;
    }
    final title = TextEditingController(),
        description = TextEditingController();
    String lessonId = choices.first.id;
    DateTime dueDate = DateTime.now().add(const Duration(days: 3));
    final saved = await showFormDialog<bool>(
      context: context,
      onDisposed: () {
        title.dispose();
        description.dispose();
      },
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Uy vazifasi berish'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: lessonId,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(20),
                    decoration: const InputDecoration(
                      labelText: 'Qaysi dars uchun?',
                    ),
                    items: choices
                        .map(
                          (l) => DropdownMenuItem(
                            value: l.id,
                            child: Text(
                              '${shortDate(l.startsAt)} • ${l.topic}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => update(() => lessonId = v ?? lessonId),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Vazifa nomi'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Tushuntirish',
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text('Muddat: ${shortDate(dueDate)}'),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (date != null && context.mounted)
                        update(
                          () => dueDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            23,
                            59,
                          ),
                        );
                    },
                  ),
                ],
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
                if (title.text.trim().isNotEmpty)
                  Navigator.pop(dialogContext, true);
              },
              child: const Text('Berish'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      final name = title.text.trim(), text = description.text.trim();
      await runCrmAction(
        context,
        () => store.addHomework(
          group.id,
          name,
          text,
          dueDate,
          lessonId: lessonId,
        ),
      );
    }
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({
    required this.store,
    required this.group,
    required this.homework,
  });

  final CrmStore store;
  final StudyGroup group;
  final Homework homework;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homework.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        if (homework.lessonId != null)
          Text(
            'Dars: ${store.lessons.where((l) => l.id == homework.lessonId).firstOrNull?.topic ?? '—'}',
            style: const TextStyle(color: AppColors.primary),
          ),
        Text(homework.description),
        const SizedBox(height: 6),
        Text(
          'Muddat: ${shortDate(homework.dueDate)}',
          style: const TextStyle(color: AppColors.muted),
        ),
        const Divider(height: 28),
        if (store.activeRole == AppRole.student)
          _StudentHomework(store: store, homework: homework)
        else
          _TeacherHomework(store: store, group: group, homework: homework),
      ],
    );
  }
}

class _StudentHomework extends StatelessWidget {
  const _StudentHomework({required this.store, required this.homework});

  final CrmStore store;
  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final result = store.resultFor(homework.id, store.activeUser.id);
    return Row(
      children: [
        Expanded(
          child: Text(
            _homeworkLabel(result.status),
            style: TextStyle(
              color: _homeworkColor(result.status),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () => _submit(context, result),
          child: Text(
            result.answer.isEmpty ? 'Javob yuborish' : 'Javobni ko‘rish',
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, HomeworkResult result) async {
    final answer = TextEditingController(text: result.answer);
    final sent = await showFormDialog<bool>(
      context: context,
      onDisposed: answer.dispose,
      builder: (context) => AlertDialog(
        title: Text(homework.title),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: answer,
                readOnly:
                    result.status == HomeworkStatus.accepted ||
                    !store
                        .studentById(store.activeUser.id, homework.groupId)
                        .active ||
                    !store.groupById(homework.groupId).active,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Javobingiz'),
              ),
              if (result.comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Ustoz izohi: ${result.comment}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yopish'),
          ),
          FilledButton(
            onPressed:
                result.status == HomeworkStatus.accepted ||
                    !store
                        .studentById(store.activeUser.id, homework.groupId)
                        .active ||
                    !store.groupById(homework.groupId).active
                ? null
                : () {
                    if (answer.text.trim().isNotEmpty)
                      Navigator.pop(context, true);
                  },
            child: const Text('Yuborish'),
          ),
        ],
      ),
    );
    if (sent == true && context.mounted)
      await runCrmAction(
        context,
        () => store.submitHomework(
          homework.id,
          store.activeUser.id,
          answer.text.trim(),
        ),
        success: 'Javob yuborildi',
      );
  }
}

class _TeacherHomework extends StatelessWidget {
  const _TeacherHomework({
    required this.store,
    required this.group,
    required this.homework,
  });

  final CrmStore store;
  final StudyGroup group;
  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final students = _visibleStudents(store, group.id);
    return Column(
      children: [
        for (final student in students)
          Builder(
            builder: (context) {
              final result = store.resultFor(homework.id, student.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(student.name),
                subtitle: Text(
                  _homeworkLabel(result.status),
                  style: TextStyle(color: _homeworkColor(result.status)),
                ),
                trailing: result.answer.isEmpty
                    ? const Text(
                        'Javob yo‘q',
                        style: TextStyle(color: AppColors.muted),
                      )
                    : OutlinedButton(
                        onPressed: () => _review(context, student, result),
                        child: const Text('Tekshirish'),
                      ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _review(
    BuildContext context,
    Student student,
    HomeworkResult result,
  ) async {
    final comment = TextEditingController(text: result.comment);
    int score = result.score ?? 5;
    bool accepted = result.status != HomeworkStatus.returned;
    final saved = await showFormDialog<bool>(
      context: context,
      onDisposed: comment.dispose,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(student.name),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'O‘quvchi javobi',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(result.answer),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: score,
                    decoration: const InputDecoration(labelText: 'Baho'),
                    items: [1, 2, 3, 4, 5]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => score = value ?? score),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comment,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Izoh'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(accepted ? 'Qabul qilinadi' : 'Qaytariladi'),
                    value: accepted,
                    onChanged: (value) =>
                        setDialogState(() => accepted = value),
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
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Saqlash'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true && context.mounted) {
      await runCrmAction(
        context,
        () => store.reviewHomework(
          homeworkId: homework.id,
          studentId: student.id,
          accepted: accepted,
          score: score,
          comment: comment.text.trim(),
        ),
        success: 'Baho saqlandi',
      );
    }
  }
}

class _JournalTab extends StatelessWidget {
  const _JournalTab({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final lessons = store
        .lessonsOf(group.id)
        .where((l) => l.status != 'cancelled')
        .toList();
    final homeworks = store.homeworksOf(group.id);
    final students = _visibleStudents(store, group.id);

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guruh jurnali',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Davomat va uy vazifalari bo‘yicha umumiy natija',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('O‘quvchi')),
                DataColumn(label: Text('Davomat')),
                DataColumn(label: Text('Uy vazifasi')),
                DataColumn(label: Text('O‘rtacha baho')),
              ],
              rows: students.map((student) {
                final attended = lessons.where((lesson) {
                  final status = store.attendance[lesson.id]?[student.id];
                  return status == AttendanceStatus.present ||
                      status == AttendanceStatus.late;
                }).length;
                final homeworkResults = homeworks
                    .map((homework) => store.resultFor(homework.id, student.id))
                    .toList();
                final accepted = homeworkResults
                    .where((result) => result.status == HomeworkStatus.accepted)
                    .length;
                final scores = homeworkResults
                    .where((result) => result.score != null)
                    .map((result) => result.score!)
                    .toList();
                final average = scores.isEmpty
                    ? '—'
                    : (scores.reduce((a, b) => a + b) / scores.length)
                          .toStringAsFixed(1);
                return DataRow(
                  cells: [
                    DataCell(Text(student.name)),
                    DataCell(Text('$attended/${lessons.length}')),
                    DataCell(Text('$accepted/${homeworks.length}')),
                    DataCell(Text(average)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

String _attendanceLabel(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => 'Keldi',
  AttendanceStatus.late => 'Kechikdi',
  AttendanceStatus.absent => 'Kelmadi',
};

String _homeworkLabel(HomeworkStatus status) => switch (status) {
  HomeworkStatus.waiting => 'Bajarilmagan',
  HomeworkStatus.submitted => 'Tekshirilmoqda',
  HomeworkStatus.accepted => 'Qabul qilindi',
  HomeworkStatus.returned => 'Qaytarildi',
};

Color _homeworkColor(HomeworkStatus status) => switch (status) {
  HomeworkStatus.waiting => AppColors.muted,
  HomeworkStatus.submitted => AppColors.warning,
  HomeworkStatus.accepted => AppColors.success,
  HomeworkStatus.returned => AppColors.danger,
};

List<Student> _visibleStudents(CrmStore store, String groupId) {
  final students = store.studentsOf(groupId);
  if (store.activeRole != AppRole.student) return students;
  return students
      .where((student) => student.id == store.activeUser.id)
      .toList();
}

class _RankingTab extends StatelessWidget {
  const _RankingTab({required this.store, required this.group});
  final CrmStore store;
  final StudyGroup group;
  @override
  Widget build(BuildContext context) {
    final students = _visibleStudents(store, group.id)
      ..sort((a, b) => store.coinsOf(b.id).compareTo(store.coinsOf(a.id)));
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'O‘quvchilar reytingi',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Davomat: 10 coin • Qabul qilingan vazifa: bahosi miqdorida coin',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          for (final student in students)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.softBlue,
                child: Text(
                  '${store.activeRole == AppRole.student ? store.rankFor(groupId: group.id) ?? '—' : 1 + students.where((s) => store.coinsOf(s.id) > store.coinsOf(student.id)).length}',
                ),
              ),
              title: Text(student.name),
              subtitle: Text(student.statusLabel),
              trailing: Text(
                '${store.coinsOf(student.id)} coin',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (students.isEmpty) const EmptyState(text: 'O‘quvchilar yo‘q'),
        ],
      ),
    );
  }
}
