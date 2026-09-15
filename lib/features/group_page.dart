import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../core/app_notice.dart';
import '../core/helpers.dart';
import '../core/user_avatar.dart';
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
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                ),
              ),
              const Expanded(child: Center(child: Text('Guruh saqlanmadi.'))),
            ],
          ),
        ),
      );
    const labels = [
      'Ma’lumot',
      'Davomat',
      'Uy vazifalari',
      'Jurnal',
      'Reyting',
    ];
    final pages = [
      _InfoTab(store: widget.store, group: group),
      _AttendanceTab(store: widget.store, group: group),
      _HomeworkTab(store: widget.store, group: group),
      _JournalTab(store: widget.store, group: group),
      _RankingTab(store: widget.store, group: group),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 16, 12, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .07),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${group.teacherName} • ${group.statusLabel}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.store.activeRole == AppRole.admin)
                              IconButton(
                                tooltip: 'Guruhni tahrirlash',
                                icon: const AppIcon('edit', size: 22),
                                onPressed: () => editStudyGroup(
                                  context,
                                  widget.store,
                                  group: group,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            children: List.generate(labels.length, (index) {
                              final selected = tab == index;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  bottom: 6,
                                ),
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: selected
                                        ? AppColors.primary
                                        : AppColors.muted,
                                    backgroundColor: selected
                                        ? AppColors.softBlue(context)
                                        : Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => setState(() => tab = index),
                                  child: Text(labels[index]),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                // Same 16px gutter and 1200 cap as the header bar above, so
                // every tab lines up with it exactly.
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final info = Row(
                        children: [
                          CircleAvatar(
                            child: Text(student.name.substring(0, 1)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  student.phone,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      // Only admin edits enrollment status; a group's own
                      // teacher can manage lessons/homework but not this.
                      final status = store.activeRole == AppRole.admin
                          ? Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final option in _enrollmentStatuses)
                                  ChoiceChip(
                                    label: Text(option.label),
                                    selected: student.status == option.value,
                                    onSelected: (_) => runCrmAction(
                                      context,
                                      () => store.setEnrollmentStatus(
                                        student.id,
                                        group.id,
                                        option.value,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : _StatusTag(student.statusLabel, student.status);
                      if (constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [info, const SizedBox(height: 8), status],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: info),
                          status,
                        ],
                      );
                    },
                  ),
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
          color: AppColors.softBlue(context),
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

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  Map<String, AttendanceStatus> values = {};
  Map<String, String> times = {};
  final topic = TextEditingController();
  // Admin only: an earlier lesson picked to fill in after its day has passed.
  String? pickedLessonId;

  @override
  void dispose() {
    topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final store = widget.store;
    final isAdmin = store.activeRole == AppRole.admin;
    final today = tashkentDate(DateTime.now());
    final allLessons = store.lessonsOf(group.id);
    final todaysLesson = allLessons.where((l) {
      final day = tashkentDate(l.startsAt);
      return day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;
    }).firstOrNull;
    // A teacher only ever works on today's lesson; an admin may reopen an
    // earlier one, which is how attendance gets fixed after the day passed.
    final lesson = isAdmin && pickedLessonId != null
        ? allLessons
                  .where((l) => l.id == store.resolveId(pickedLessonId!))
                  .firstOrNull ??
              todaysLesson
        : todaysLesson;

    if (lesson == null) {
      return _buildStartLesson(context, group, today, allLessons);
    }

    final students = _visibleStudents(store, group.id);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Davomat',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            lesson.topic,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isAdmin && allLessons.length > 1) ...[
            const SizedBox(height: 14),
            _adminLessonPicker(allLessons, lesson),
          ],
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
                  final came =
                      selected == AttendanceStatus.present ||
                      selected == AttendanceStatus.late;
                  final late = selected == AttendanceStatus.late;
                  final arrivedAt =
                      times[student.id] ??
                      widget.store.attendanceTimes[lesson.id]?[student.id];
                  final canEdit =
                      widget.store.canMarkLesson(lesson) &&
                      (student.active ||
                          widget.store.activeRole == AppRole.admin);
                  void setStatus(AttendanceStatus status) =>
                      setState(() => values[student.id] = status);
                  final control = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        came ? 'Keldi' : 'Kelmadi',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _attendanceColor(selected),
                        ),
                      ),
                      Switch(
                        value: came,
                        onChanged: !canEdit
                            ? null
                            : (value) => setState(() {
                                values[student.id] = value
                                    ? (late
                                          ? AttendanceStatus.late
                                          : AttendanceStatus.present)
                                    : AttendanceStatus.absent;
                                // Default the arrival time to the lesson's
                                // own start time; a teacher may still adjust
                                // it below.
                                if (value && arrivedAt == null) {
                                  final start = tashkentDate(lesson.startsAt);
                                  times[student.id] =
                                      '${start.hour.toString().padLeft(2, '0')}:'
                                      '${start.minute.toString().padLeft(2, '0')}';
                                }
                              }),
                      ),
                      if (came)
                        FilterChip(
                          label: const Text('Kechikdi'),
                          selected: late,
                          onSelected: !canEdit
                              ? null
                              : (value) => setStatus(
                                  value
                                      ? AttendanceStatus.late
                                      : AttendanceStatus.present,
                                ),
                        ),
                      if (came)
                        ActionChip(
                          avatar: const Icon(Icons.schedule, size: 16),
                          label: Text(arrivedAt ?? 'Vaqt kiritish'),
                          onPressed: !canEdit
                              ? null
                              : () async {
                                  final parsed = arrivedAt?.split(':');
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: parsed == null
                                        ? TimeOfDay.now()
                                        : TimeOfDay(
                                            hour: int.parse(parsed[0]),
                                            minute: int.parse(parsed[1]),
                                          ),
                                  );
                                  if (picked == null) return;
                                  setState(
                                    () => times[student.id] =
                                        '${picked.hour.toString().padLeft(2, '0')}:'
                                        '${picked.minute.toString().padLeft(2, '0')}',
                                  );
                                },
                        ),
                    ],
                  );
                  if (constraints.maxWidth < 650) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name),
                        const SizedBox(height: 8),
                        control,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: Text(student.name)),
                      control,
                    ],
                  );
                },
              ),
            ),
          if (widget.store.activeRole != AppRole.student)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: values.isEmpty || !widget.store.canMarkLesson(lesson)
                    ? null
                    : () {
                        final changes = Map<String, AttendanceStatus>.of(
                          values,
                        );
                        final changeTimes = Map<String, String?>.of(times);
                        runCrmAction(
                          context,
                          () => widget.store.saveAttendance(
                            lesson.id,
                            changes,
                            times: changeTimes,
                          ),
                          success: 'Davomat saqlandi',
                        );
                        setState(() {
                          values.clear();
                          times.clear();
                        });
                      },
                child: const Text('Saqlash'),
              ),
            ),
        ],
      ),
    );
  }

  /// Lets an admin reopen an earlier lesson once its day has passed; a
  /// teacher never sees this and always works on today's lesson.
  Widget _adminLessonPicker(List<Lesson> lessons, Lesson? selected) => SizedBox(
    width: 320,
    child: DropdownButtonFormField<String>(
      key: ValueKey(selected?.id),
      initialValue: selected?.id,
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      decoration: const InputDecoration(labelText: 'Darsni tanlang'),
      items: lessons
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
      onChanged: (id) => setState(() {
        pickedLessonId = id;
        values.clear();
        times.clear();
      }),
    ),
  );

  /// No lesson exists for today yet. A teacher may start one (topic only)
  /// while the group's scheduled day/time window is open; admin may do it
  /// any time, or reopen an earlier lesson instead. Everyone else just sees
  /// why attendance isn't open.
  Widget _buildStartLesson(
    BuildContext context,
    StudyGroup group,
    DateTime today,
    List<Lesson> lessons,
  ) {
    final isAdmin = widget.store.activeRole == AppRole.admin;
    final isTeacher =
        widget.store.activeRole == AppRole.teacher &&
        widget.store.canManageGroup(group.id);
    // isScheduledNow does its own Tashkent conversion, so it takes the raw
    // instant — passing the already-converted `today` would shift it +5h.
    final scheduledNow = widget.store.isScheduledNow(group);
    final canStart = group.active && (isAdmin || (isTeacher && scheduledNow));
    if (!canStart) {
      final message = !group.active
          ? 'Guruh faol emas.'
          : isTeacher
          ? _scheduleUnavailableReason(group, today)
          : 'Bugungi dars hali boshlanmagan.';
      return Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmptyState(text: message, icon: Icons.schedule_outlined),
            if (isAdmin && lessons.isNotEmpty) ...[
              const SizedBox(height: 8),
              _adminLessonPicker(lessons, null),
            ],
          ],
        ),
      );
    }
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Davomat',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Bugungi darsni boshlash uchun mavzusini kiriting.',
            style: TextStyle(color: AppColors.muted),
          ),
          if (isAdmin && lessons.isNotEmpty) ...[
            const SizedBox(height: 14),
            _adminLessonPicker(lessons, null),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: topic,
            decoration: const InputDecoration(labelText: 'Dars nomi'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: topic.text.trim().isEmpty
                  ? null
                  : () => _startLesson(context, group, today),
              child: const Text('Darsni boshlash'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startLesson(
    BuildContext context,
    StudyGroup group,
    DateTime today,
  ) async {
    final name = topic.text.trim();
    final startsAt = group.lessonStartTime.isEmpty
        ? DateTime.now()
        : tashkentInstant(
            today.year,
            today.month,
            today.day,
            int.parse(group.lessonStartTime.split(':')[0]),
            int.parse(group.lessonStartTime.split(':')[1]),
          );
    await runCrmAction(
      context,
      () => widget.store.addLesson(group.id, name, startsAt),
    );
    topic.clear();
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
          title: const Text('Avval darsni boshlang'),
          content: const Text(
            'Uy vazifasi darsga bog‘lanadi. Davomat bo‘limida bugungi dars nomini kiriting.',
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
    final title = TextEditingController();
    String lessonId = choices.first.id;
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    Uint8List? fileBytes;
    String? fileName;
    final saved = await showFormDialog<bool>(
      context: context,
      onDisposed: title.dispose,
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
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Vazifa (nima qilish kerak)',
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
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file_outlined),
                    title: Text(fileName ?? 'Fayl biriktirish (ixtiyoriy)'),
                    trailing: fileName == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => update(() {
                              fileBytes = null;
                              fileName = null;
                            }),
                          ),
                    onTap: () async {
                      final file = await FilePicker.pickFile();
                      if (file == null) return;
                      final bytes = await file.readAsBytes();
                      update(() {
                        fileBytes = bytes;
                        fileName = file.name;
                      });
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
      final name = title.text.trim();
      await runCrmAction(
        context,
        () => store.addHomework(
          group.id,
          name,
          '',
          dueDate,
          lessonId: lessonId,
          fileBytes: fileBytes,
          fileName: fileName,
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
        if (homework.description.isNotEmpty) Text(homework.description),
        const SizedBox(height: 6),
        Text(
          'Muddat: ${shortDate(homework.dueDate)}',
          style: const TextStyle(color: AppColors.muted),
        ),
        if (homework.filePath != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => runCrmAction(context, () async {
              final url = await store.homeworkFileUrl(homework.filePath!);
              if (!context.mounted) return;
              await launchUrl(Uri.parse(url));
            }),
            icon: const Icon(Icons.attach_file_outlined, size: 18),
            label: Text(homework.fileName ?? 'Fayl'),
          ),
        ],
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

const _uzMonths = [
  'Yanvar',
  'Fevral',
  'Mart',
  'Aprel',
  'May',
  'Iyun',
  'Iyul',
  'Avgust',
  'Sentyabr',
  'Oktyabr',
  'Noyabr',
  'Dekabr',
];
String _monthLabel(DateTime month) =>
    '${_uzMonths[month.month - 1]} ${month.year}';

/// Blue = submitted, green = accepted, red = not sent or returned — the
/// journal's own reading of homework status, distinct from the muted/warning
/// colors used for the status chip elsewhere in the app.
Color _journalHomeworkColor(HomeworkStatus status) => switch (status) {
  HomeworkStatus.submitted => AppColors.primary,
  HomeworkStatus.accepted => AppColors.success,
  HomeworkStatus.waiting || HomeworkStatus.returned => AppColors.danger,
};

class _JournalTab extends StatefulWidget {
  const _JournalTab({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  State<_JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<_JournalTab> {
  DateTime? selectedMonth;

  @override
  Widget build(BuildContext context) {
    final store = widget.store, group = widget.group;
    final allLessons =
        store.lessonsOf(group.id).where((l) => l.status != 'cancelled').toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final students = _visibleStudents(store, group.id);

    final months = <DateTime>{
      for (final l in allLessons)
        DateTime(tashkentDate(l.startsAt).year, tashkentDate(l.startsAt).month),
    }.toList()..sort((a, b) => b.compareTo(a));
    // A month that no longer has lessons falls back to the whole history.
    if (selectedMonth != null && !months.contains(selectedMonth)) {
      selectedMonth = null;
    }

    // null = "Hammasi": the whole history, which is the default view.
    final lessons = selectedMonth == null
        ? allLessons
        : allLessons.where((l) {
            final d = tashkentDate(l.startsAt);
            return d.year == selectedMonth!.year &&
                d.month == selectedMonth!.month;
          }).toList();
    final homeworks = store
        .homeworksOf(group.id)
        .where((h) => lessons.any((l) => l.id == h.lessonId))
        .toList();
    Homework? homeworkFor(Lesson lesson) =>
        homeworks.where((h) => h.lessonId == lesson.id).firstOrNull;

    final attendanceScore = <String, ({int done, int total})>{};
    final homeworkScore = <String, ({int done, int total})>{};
    for (final student in students) {
      // Only lessons the student was actually enrolled for count against them.
      final applicable = lessons
          .where((l) => student.enrolledOn(l.startsAt))
          .toList();
      attendanceScore[student.id] = (
        done: applicable.where((l) {
          final status = store.attendance[l.id]?[student.id];
          return status == AttendanceStatus.present ||
              status == AttendanceStatus.late;
        }).length,
        total: applicable.length,
      );
      final ownHomework = homeworks
          .where(
            (h) => students.any(
              (s) =>
                  s.id == student.id &&
                  lessons.any(
                    (l) => l.id == h.lessonId && student.enrolledOn(l.startsAt),
                  ),
            ),
          )
          .toList();
      homeworkScore[student.id] = (
        done: ownHomework
            .where(
              (h) =>
                  store.resultFor(h.id, student.id).status ==
                  HomeworkStatus.accepted,
            )
            .length,
        total: ownHomework.length,
      );
    }
    double percentOf(({int done, int total}) score) =>
        score.total == 0 ? 0 : score.done * 100 / score.total;
    final sortedStudents = [...students]
      ..sort((a, b) {
        final scoreA =
            (percentOf(attendanceScore[a.id]!) +
                percentOf(homeworkScore[a.id]!)) /
            2;
        final scoreB =
            (percentOf(attendanceScore[b.id]!) +
                percentOf(homeworkScore[b.id]!)) /
            2;
        return scoreB.compareTo(scoreA);
      });

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guruh jurnali',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Butun davr bo‘yicha davomat va uy vazifasi; '
                    'eng yaxshi natija tepada',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              );
              final picker = months.isEmpty
                  ? const SizedBox.shrink()
                  : DropdownButton<DateTime?>(
                      value: selectedMonth,
                      borderRadius: BorderRadius.circular(16),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Hammasi'),
                        ),
                        for (final m in months)
                          DropdownMenuItem(
                            value: m,
                            child: Text(_monthLabel(m)),
                          ),
                      ],
                      onChanged: (m) => setState(() => selectedMonth = m),
                    );
              if (constraints.maxWidth < 560) {
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: const [
              _JournalLegend(
                mark: '+',
                color: AppColors.success,
                label: 'Keldi',
              ),
              _JournalLegend(
                mark: '+',
                color: AppColors.warning,
                label: 'Kechikdi',
              ),
              _JournalLegend(
                mark: '−',
                color: AppColors.danger,
                label: 'Kelmadi',
              ),
              _JournalLegend(
                mark: '·',
                color: AppColors.muted,
                label: 'Belgilanmagan',
              ),
              _JournalLegend(
                icon: Icons.check_circle,
                color: AppColors.primary,
                label: 'Vazifa yuborilgan',
              ),
              _JournalLegend(
                icon: Icons.check_circle,
                color: AppColors.success,
                label: 'Vazifa qabul qilingan',
              ),
              _JournalLegend(
                icon: Icons.check_circle,
                color: AppColors.danger,
                label: 'Vazifa yuborilmagan/qaytarilgan',
              ),
              _JournalSwatchLegend(label: 'Guruhda yo‘q edi'),
            ],
          ),
          const SizedBox(height: 18),
          if (lessons.isEmpty)
            EmptyState(
              text: months.isEmpty
                  ? 'Darslar hali yaratilmagan'
                  : 'Bu oyda dars bo‘lmagan',
            )
          else
            // Scrolls when the lesson columns overflow, but stretches to fill
            // the width when they don't, so the table never looks stranded.
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowHeight: 64,
                    columns: [
                      const DataColumn(label: Text('#')),
                      const DataColumn(label: Text('O‘quvchi')),
                      for (final (index, lesson) in lessons.indexed)
                        DataColumn(
                          label: _LessonColumnLabel(
                            index: index + 1,
                            lesson: lesson,
                            endTime: group.lessonEndTime,
                          ),
                        ),
                      const DataColumn(label: Text('Davomat'), numeric: true),
                      const DataColumn(label: Text('Uy vazifa'), numeric: true),
                    ],
                    rows: [
                      for (final (index, student) in sortedStudents.indexed)
                        DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UserAvatar(
                                    store: store,
                                    user: store.users.firstWhere(
                                      (u) => u.id == student.id,
                                    ),
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(student.name),
                                  if (student.status != 'active') ...[
                                    const SizedBox(width: 8),
                                    _StatusTag(
                                      student.statusLabel,
                                      student.status,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            for (final lesson in lessons)
                              DataCell(
                                !student.enrolledOn(lesson.startsAt)
                                    ? const _JournalAbsentCell()
                                    : _JournalCell(
                                        attendance: store
                                            .attendance[lesson.id]?[student.id],
                                        homework: homeworkFor(lesson),
                                        homeworkStatus:
                                            homeworkFor(lesson) == null
                                            ? null
                                            : store
                                                  .resultFor(
                                                    homeworkFor(lesson)!.id,
                                                    student.id,
                                                  )
                                                  .status,
                                      ),
                              ),
                            DataCell(_ScoreText(attendanceScore[student.id]!)),
                            DataCell(_ScoreText(homeworkScore[student.id]!)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One legend entry: either the glyph a cell prints, or the icon it corners.
class _JournalLegend extends StatelessWidget {
  const _JournalLegend({
    this.icon,
    this.mark,
    required this.color,
    required this.label,
  }) : assert(icon != null || mark != null, 'needs an icon or a mark');
  final IconData? icon;
  final String? mark;
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 15,
        child: mark == null
            ? Icon(icon, size: 15, color: color)
            : Text(
                mark!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  );
}

class _JournalSwatchLegend extends StatelessWidget {
  const _JournalSwatchLegend({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  );
}

/// A lesson cell for a student who wasn't enrolled in the group yet, or
/// anymore, on that lesson's date — distinct from being marked absent.
class _JournalAbsentCell extends StatelessWidget {
  const _JournalAbsentCell();
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Bu sanada guruhda emas edi',
    child: Container(
      width: 34,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}

const _uzMonthsShort = [
  'Yan',
  'Fev',
  'Mar',
  'Apr',
  'May',
  'Iyn',
  'Iyl',
  'Avg',
  'Sen',
  'Okt',
  'Noy',
  'Dek',
];

String _hhmm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

/// A lesson column's heading: its number in the period, the date, and the
/// time range, stacked the way a paper journal lists its sessions.
class _LessonColumnLabel extends StatelessWidget {
  const _LessonColumnLabel({
    required this.index,
    required this.lesson,
    required this.endTime,
  });
  final int index;
  final Lesson lesson;
  final String endTime;
  @override
  Widget build(BuildContext context) {
    final start = tashkentDate(lesson.startsAt);
    return Tooltip(
      message: lesson.topic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$index',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Text(
            '${start.day}-${_uzMonthsShort[start.month - 1]}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            endTime.isEmpty ? _hhmm(start) : '${_hhmm(start)} - $endTime',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// "9 / 9 (100 %)" — the count first, the share of it second.
class _ScoreText extends StatelessWidget {
  const _ScoreText(this.score);
  final ({int done, int total}) score;
  @override
  Widget build(BuildContext context) {
    if (score.total == 0) {
      return const Text('—', style: TextStyle(color: AppColors.muted));
    }
    final percent = (score.done * 100 / score.total).round();
    return Text(
      '${score.done} / ${score.total} ($percent %)',
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
  }
}

/// One lesson's cell: the attendance mark in the middle, with the homework
/// marker tucked into the corner when that lesson carries one.
class _JournalCell extends StatelessWidget {
  const _JournalCell({
    required this.attendance,
    required this.homework,
    required this.homeworkStatus,
  });
  final AttendanceStatus? attendance;
  final Homework? homework;
  final HomeworkStatus? homeworkStatus;
  @override
  Widget build(BuildContext context) {
    final parts = [
      attendance == null
          ? 'Davomat belgilanmagan'
          : _attendanceLabel(attendance!),
      if (homework != null && homeworkStatus != null)
        'Uy vazifa: ${_homeworkLabel(homeworkStatus!)}',
    ];
    final mark = switch (attendance) {
      AttendanceStatus.present || AttendanceStatus.late => '+',
      AttendanceStatus.absent => '−',
      null => '·',
    };
    return Tooltip(
      message: parts.join(' • '),
      child: SizedBox(
        width: 38,
        height: 30,
        child: Stack(
          children: [
            Center(
              child: Text(
                mark,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _attendanceColor(attendance),
                ),
              ),
            ),
            if (homework != null)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle,
                  size: 12,
                  color: _journalHomeworkColor(homeworkStatus!),
                ),
              ),
          ],
        ),
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

Color _attendanceColor(AttendanceStatus? status) => switch (status) {
  AttendanceStatus.present => AppColors.success,
  AttendanceStatus.late => AppColors.warning,
  AttendanceStatus.absent => AppColors.danger,
  null => AppColors.muted,
};

/// Why a teacher can't start/mark today's lesson right now.
String _scheduleUnavailableReason(StudyGroup group, DateTime today) {
  if (group.weekDays.isNotEmpty && !group.weekDays.contains(today.weekday)) {
    return 'Bugun bu guruh uchun dars kuni emas.';
  }
  if (group.lessonStartTime.isNotEmpty && group.lessonEndTime.isNotEmpty) {
    return 'Davomat faqat dars vaqtida '
        '(${group.lessonStartTime}–${group.lessonEndTime}) ochiladi.';
  }
  return 'Hozircha davomat ochilmagan.';
}

const _enrollmentStatuses = [
  (value: 'active', label: 'Aktiv'),
  (value: 'completed', label: 'Tugatgan'),
  (value: 'left', label: 'Ketgan'),
];

Color _enrollmentColor(String status) => switch (status) {
  'left' => AppColors.danger,
  'completed' => AppColors.primary,
  _ => AppColors.success,
};

/// Read-only status label; only admin gets an editable control (see
/// [_InfoTab]) so a group's own teacher cannot move a student in or out.
class _StatusTag extends StatelessWidget {
  const _StatusTag(this.label, this.status);
  final String label;
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = _enrollmentColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

List<Student> _visibleStudents(CrmStore store, String groupId) {
  final students = store.studentsOf(groupId);
  if (store.activeRole != AppRole.student) return students;
  return students
      .where((student) => student.id == store.activeUser.id)
      .toList();
}

/// A signed points figure: green above zero, red below, muted at zero.
class _SignedPoints extends StatelessWidget {
  const _SignedPoints(this.value);
  final int value;
  @override
  Widget build(BuildContext context) {
    final color = value > 0
        ? AppColors.success
        : value < 0
        ? AppColors.danger
        : AppColors.muted;
    final sign = value > 0 ? '+' : '';
    return Text(
      '$sign$value',
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _RankingTab extends StatelessWidget {
  const _RankingTab({required this.store, required this.group});
  final CrmStore store;
  final StudyGroup group;
  @override
  Widget build(BuildContext context) {
    final students = _visibleStudents(store, group.id)
      ..sort((a, b) => store.pointsOf(b.id).compareTo(store.pointsOf(a.id)));
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
            'Davomat: 10 ball • Qabul qilingan vazifa: bahosi miqdorida ball • '
            'ustiga bosib ball tarixini ko‘rish mumkin',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (students.isEmpty)
            const EmptyState(text: 'O‘quvchilar yo‘q')
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 20,
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('O‘quvchi')),
                      DataColumn(label: Text('Dars ballari'), numeric: true),
                      DataColumn(label: Text('Rag‘bat'), numeric: true),
                      DataColumn(label: Text('Jarima'), numeric: true),
                      DataColumn(label: Text('Jami'), numeric: true),
                    ],
                    rows: [
                      for (final (index, student) in students.indexed)
                        DataRow(
                          onSelectChanged: (_) =>
                              _showAwardHistory(context, store, group, student),
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  UserAvatar(
                                    store: store,
                                    user: store.users.firstWhere(
                                      (u) => u.id == student.id,
                                    ),
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(student.name),
                                  if (student.status != 'active') ...[
                                    const SizedBox(width: 8),
                                    _StatusTag(
                                      student.statusLabel,
                                      student.status,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              Text('${store.lessonPointsOf(student.id)}'),
                            ),
                            DataCell(
                              _SignedPoints(store.bonusPointsOf(student.id)),
                            ),
                            DataCell(
                              _SignedPoints(store.penaltyPointsOf(student.id)),
                            ),
                            DataCell(
                              Text(
                                '${store.pointsOf(student.id)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Every reward and penalty a pupil has been given, newest first, with a
/// form for the staff who may add another.
Future<void> _showAwardHistory(
  BuildContext context,
  CrmStore store,
  StudyGroup group,
  Student student,
) {
  final amount = TextEditingController();
  final note = TextEditingController();
  return showFormDialog<void>(
    context: context,
    onDisposed: () {
      amount.dispose();
      note.dispose();
    },
    builder: (dialogContext) => AlertDialog(
      title: Text(student.name),
      content: SizedBox(
        width: 460,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final awards = store.awardsOf(student.id);
            Future<void> submit(int sign) async {
              final value = int.tryParse(amount.text.trim()) ?? 0;
              if (value <= 0) {
                showAppNotice(context, 'Musbat ball kiriting.', isError: true);
                return;
              }
              await runCrmAction(
                context,
                () => store.addScoreAward(
                  studentId: student.id,
                  groupId: group.id,
                  amount: sign * value,
                  note: note.text.trim(),
                ),
                success: 'Ball saqlandi',
              );
              amount.clear();
              note.clear();
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text('Dars ballari: ${store.lessonPointsOf(student.id)}'),
                      Text('Jami: ${store.pointsOf(student.id)}'),
                    ],
                  ),
                  const Divider(height: 26),
                  if (awards.isEmpty)
                    const Text(
                      'Hali qo‘shimcha ball berilmagan.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  for (final award in awards)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 52,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _SignedPoints(award.amount),
                        ),
                      ),
                      title: Text(award.note.isEmpty ? '—' : award.note),
                      subtitle: Text(
                        '${award.byName} • ${shortDate(award.createdAt)}',
                      ),
                    ),
                  if (!store.scoreAwardsReady)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Qo‘shimcha ball imkoniyati bazaga hali qo‘shilmagan.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  else if (store.canManageGroup(group.id)) ...[
                    const Divider(height: 26),
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ball',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: note,
                            decoration: const InputDecoration(
                              labelText: 'Izoh',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => submit(1),
                            icon: const Icon(Icons.add),
                            label: const Text('Rag‘bat'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            onPressed: () => submit(-1),
                            icon: const Icon(Icons.remove),
                            label: const Text('Jarima'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Yopish'),
        ),
      ],
    ),
  );
}
