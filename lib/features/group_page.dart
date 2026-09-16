import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/migration.dart';
import '../core/migration_setup.dart';
import '../core/app_icon.dart';
import '../core/helpers.dart';
import '../core/navigation.dart';
import '../core/user_avatar.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import 'group_editor.dart';
import 'homework_pages.dart';
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
    if (oldWidget.startTab != widget.startTab) tab = widget.startTab;
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

  /// Under the router the tab lives in the address; on its own the page
  /// just switches, as a single screen in a test does.
  void _openTab(String groupId, int index) {
    if (isRouted(context)) {
      goTo(context, groupPath(groupId, groupTabs[index]));
    } else {
      setState(() => tab = index);
    }
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
                  onPressed: () => goBack(context, '/groups'),
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
      GroupHomeworkTab(store: widget.store, group: group),
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
                              onPressed: () => goBack(context, '/groups'),
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
                                onPressed: () => goOr(
                                  context,
                                  '${groupPath(group.id)}/edit',
                                  () => editStudyGroup(
                                    context,
                                    widget.store,
                                    group: group,
                                  ),
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
                                  onPressed: () => _openTab(group.id, index),
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
                                PersonName(
                                  userId: student.id,
                                  name: student.name,
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
                      // Read-only here for everyone, admin included: the
                      // status is changed from the pupil's own profile.
                      final status = StatusTag(
                        student.statusLabel,
                        student.status,
                      );
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

const _uzMonths = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentabr',
  'oktabr',
  'noyabr',
  'dekabr',
];
String _monthLabel(DateTime month) {
  final name = _uzMonths[month.month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
}

/// Who handed the points out: the name, and what they are in the centre.
String _giverLabel(ScoreAward award) => switch (award.byRole) {
  AppRole.admin => '${award.byName} • Admin',
  AppRole.teacher => '${award.byName} • Ustoz',
  _ => award.byName,
};

/// "15-sentabr 20:21" — the centre's own clock, whatever the device's is.
String _dayTimeLabel(DateTime instant) {
  final local = tashkentDate(instant);
  return '${local.day}-${_uzMonths[local.month - 1]} ${_hhmm(local)}';
}

/// Blue = submitted, green = accepted, red = not sent or returned — the
/// journal's own reading of homework status, distinct from the muted/warning
/// colors used for the status chip elsewhere in the app.
Color _journalHomeworkColor(HomeworkStatus status) => switch (status) {
  HomeworkStatus.submitted => AppColors.primary,
  HomeworkStatus.accepted => AppColors.rewardGreen,
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
                  : SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<DateTime?>(
                        initialValue: selectedMonth,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(16),
                        decoration: const InputDecoration(
                          labelText: 'Davr',
                          prefixIcon: Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                          ),
                          isDense: true,
                        ),
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
                      ),
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
                    horizontalMargin: 14,
                    headingRowHeight: 64,
                    columns: [
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
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
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
                                    StatusTag(
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
                            DataCell(
                              _PercentBadge(attendanceScore[student.id]!),
                            ),
                            DataCell(_PercentBadge(homeworkScore[student.id]!)),
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

/// A share as one coloured figure: green from 80%, yellow from 60%, red
/// below. The raw counts are not what a journal is read for.
class _PercentBadge extends StatelessWidget {
  const _PercentBadge(this.score);
  final ({int done, int total}) score;

  @override
  Widget build(BuildContext context) {
    if (score.total == 0) {
      return const Text('—', style: TextStyle(color: AppColors.muted));
    }
    final percent = (score.done * 100 / score.total).round();
    final color = percent >= 80
        ? AppColors.rewardGreen
        : percent >= 60
        ? AppColors.warning
        : AppColors.penaltyRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        '$percent%',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
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
        'Uy vazifa: ${homeworkStatusLabel(homeworkStatus!)}',
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

List<Student> _visibleStudents(CrmStore store, String groupId) {
  final students = store.studentsOf(groupId);
  if (store.activeRole != AppRole.student) return students;
  return students
      .where((student) => student.id == store.activeUser.id)
      .toList();
}

/// A signed points figure as a badge: bright green above zero, bright red
/// below, and a plain dash at zero so the board reads at a glance.
/// Points earned by working, not granted: green when there are any, muted
/// when the pupil has none yet.
class _EarnedPoints extends StatelessWidget {
  const _EarnedPoints(this.value);
  final int value;
  @override
  Widget build(BuildContext context) => value == 0
      ? const Text('—', style: TextStyle(color: AppColors.muted))
      : Text(
          '$value',
          style: const TextStyle(
            color: AppColors.rewardGreen,
            fontWeight: FontWeight.w600,
          ),
        );
}

class _SignedPoints extends StatelessWidget {
  const _SignedPoints(this.value);
  final int value;
  @override
  Widget build(BuildContext context) {
    if (value == 0) {
      return const Text('—', style: TextStyle(color: AppColors.muted));
    }
    final reward = value > 0;
    final color = reward ? AppColors.rewardGreen : AppColors.penaltyRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reward ? Icons.star_rounded : Icons.bolt_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${reward ? '+' : ''}$value',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// The first three places wear a crown; everyone else just gets a number.
class _RankBadge extends StatelessWidget {
  const _RankBadge(this.rank);
  final int rank;
  @override
  Widget build(BuildContext context) {
    if (rank > 3) {
      return Text(
        '$rank',
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final color = switch (rank) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      _ => AppColors.bronze,
    };
    return Tooltip(
      message: '$rank-o‘rin',
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .18),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: const Text('👑', style: TextStyle(fontSize: 15)),
      ),
    );
  }
}

/// The running total, as the board's headline figure: points are green when
/// they are in the black and red when they are not — no other colour.
class _TotalPoints extends StatelessWidget {
  const _TotalPoints(this.value);
  final int value;
  @override
  Widget build(BuildContext context) {
    final color = value < 0 ? AppColors.penaltyRed : AppColors.rewardGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$value ball',
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RankingTab extends StatefulWidget {
  const _RankingTab({required this.store, required this.group});
  final CrmStore store;
  final StudyGroup group;
  @override
  State<_RankingTab> createState() => _RankingTabState();
}

class _RankingTabState extends State<_RankingTab> {
  // Purely a what-if: the picked pupils are never stored anywhere, the team
  // only lives as long as this tab is open.
  bool teamMode = false;
  final team = <String>{};

  @override
  Widget build(BuildContext context) {
    final store = widget.store, group = widget.group;
    final students = _visibleStudents(store, group.id)
      ..sort((a, b) => store.pointsOf(b.id).compareTo(store.pointsOf(a.id)));
    team.retainWhere((id) => students.any((s) => s.id == id));
    // Staff get a give-points button on every row; it stays visible but
    // disabled when the database has no awards table yet, so the reason is
    // on screen instead of the button simply being missing.
    final canAward = store.canManageGroup(group.id) && !teamMode;

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
                    '🏆 O‘quvchilar reytingi',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Davomat: 10 ball • Qabul qilingan vazifa: bahosi miqdorida '
                    'ball • ustiga bosib ball tarixini ko‘rish mumkin',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              );
              final toggle = students.length < 2
                  ? const SizedBox.shrink()
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: teamMode
                            ? AppColors.muted
                            : AppColors.rewardGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => setState(() {
                        teamMode = !teamMode;
                        team.clear();
                      }),
                      icon: Icon(
                        teamMode ? Icons.close_rounded : Icons.groups_2_rounded,
                        size: 20,
                      ),
                      label: Text(teamMode ? 'Yopish' : 'Jamoa tuzish'),
                    );
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 12), toggle],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  toggle,
                ],
              );
            },
          ),
          if (teamMode) ...[
            const SizedBox(height: 16),
            _TeamCard(
              store: store,
              students: students,
              team: team,
              onClear: () => setState(team.clear),
            ),
          ],
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
                    showCheckboxColumn: teamMode,
                    // The board reads as one list, without ruled lines
                    // between the pupils.
                    dividerThickness: 0,
                    columns: [
                      const DataColumn(label: Text('#')),
                      const DataColumn(label: Text('O‘quvchi')),
                      const DataColumn(label: Text('Uy vazifa'), numeric: true),
                      const DataColumn(
                        label: Text('Darsda qatnashish'),
                        numeric: true,
                      ),
                      const DataColumn(label: Text('Rag‘bat'), numeric: true),
                      const DataColumn(label: Text('Jarima'), numeric: true),
                      const DataColumn(label: Text('Jami'), numeric: true),
                      if (canAward) const DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final (index, student) in students.indexed)
                        DataRow(
                          selected: teamMode && team.contains(student.id),
                          // In team mode a tap picks the pupil for the
                          // what-if; otherwise it opens their history.
                          onSelectChanged: (_) => teamMode
                              ? setState(
                                  () => team.contains(student.id)
                                      ? team.remove(student.id)
                                      : team.add(student.id),
                                )
                              : _showAwardHistory(
                                  context,
                                  store,
                                  group,
                                  student,
                                ),
                          cells: [
                            DataCell(_RankBadge(index + 1)),
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
                                  Text(
                                    student.name,
                                    style: TextStyle(
                                      fontWeight: index < 3
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  if (student.status != 'active') ...[
                                    const SizedBox(width: 8),
                                    StatusTag(
                                      student.statusLabel,
                                      student.status,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              _EarnedPoints(store.homeworkPointsOf(student.id)),
                            ),
                            DataCell(
                              _EarnedPoints(
                                store.attendancePointsOf(student.id),
                              ),
                            ),
                            DataCell(
                              _SignedPoints(store.bonusPointsOf(student.id)),
                            ),
                            DataCell(
                              _SignedPoints(store.penaltyPointsOf(student.id)),
                            ),
                            DataCell(_TotalPoints(store.pointsOf(student.id))),
                            if (canAward)
                              DataCell(
                                IconButton(
                                  tooltip: 'Ball qo‘shish',
                                  onPressed: () => showAddAward(
                                    context,
                                    store,
                                    group,
                                    student,
                                  ),
                                  icon: const Icon(
                                    Icons.add_circle_rounded,
                                    color: AppColors.rewardGreen,
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

/// The what-if panel: pick pupils and see what one team of them would score
/// and where that would place against everyone left on the board.
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.store,
    required this.students,
    required this.team,
    required this.onClear,
  });

  final CrmStore store;
  final List<Student> students;
  final Set<String> team;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final members = students.where((s) => team.contains(s.id)).toList();
    final total = members.fold(0, (sum, s) => sum + store.pointsOf(s.id));
    // The team stands in for its own members, so it is ranked against the
    // pupils who stayed out of it.
    final outsiders = students.where((s) => !team.contains(s.id)).toList();
    final rank =
        1 + outsiders.where((s) => store.pointsOf(s.id) > total).length;
    // Top of the board is green, the bottom red, anything between amber.
    final places = outsiders.length + 1;
    final rankColor = rank == 1
        ? AppColors.rewardGreen
        : rank >= places
        ? AppColors.penaltyRed
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.rewardGreen.withValues(alpha: .18),
            AppColors.rewardGreen.withValues(alpha: .06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.rewardGreen.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '⚔️ Vaqtinchalik jamoa',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (members.isNotEmpty)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tozalash'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (members.length < 2)
            Text(
              members.isEmpty
                  ? 'Ballarini birlashtirish uchun jadvaldan kamida ikki '
                        'o‘quvchini belgilang.'
                  : 'Yana kamida bitta o‘quvchini belgilang.',
              style: const TextStyle(color: AppColors.muted),
            )
          else ...[
            Text(
              members.map((s) => s.name).join(' + '),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TeamStat(
                  icon: Icons.stars_rounded,
                  label: 'Jamoa bali',
                  value: '$total',
                  color: AppColors.rewardGreen,
                ),
                _TeamStat(
                  icon: Icons.leaderboard_rounded,
                  label: 'O‘rin',
                  value: '$rank',
                  color: rankColor,
                ),
                _TeamStat(
                  icon: Icons.group_rounded,
                  label: 'A’zolar',
                  value: '${members.length}',
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              rank == 1
                  ? 'Bu jamoa birinchi o‘rinni egallardi 👑'
                  : 'Bu jamoa $rank-o‘rinda bo‘lardi.',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamStat extends StatelessWidget {
  const _TeamStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

/// Every reward and penalty a pupil has been given, newest first, with a
/// form for the staff who may add another.
Future<void> _showAwardHistory(
  BuildContext context,
  CrmStore store,
  StudyGroup group,
  Student student,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(student.name),
      content: SizedBox(
        width: 460,
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final awards = store.awardsOf(student.id);
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
                      // Wide enough to keep the notes lined up, but free to
                      // grow: a four-digit penalty must not overflow it.
                      leading: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 64),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [_SignedPoints(award.amount)],
                        ),
                      ),
                      title: Text(
                        award.note.isEmpty ? 'Izohsiz' : award.note,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: award.note.isEmpty ? AppColors.muted : null,
                        ),
                      ),
                      subtitle: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _giverLabel(award),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '   ${_dayTimeLabel(award.createdAt)}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (store.canManageGroup(group.id)) ...[
                    const Divider(height: 26),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.rewardGreen,
                        ),
                        onPressed: () =>
                            showAddAward(context, store, group, student),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ball qo‘shish'),
                      ),
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

/// One window for handing out points: the number carries its own sign, so a
/// plain "10" rewards and a "-10" fines, and the preview says which as it is
/// typed.
Future<void> showAddAward(
  BuildContext context,
  CrmStore store,
  StudyGroup group,
  Student student,
) {
  // Without the awards table there is nowhere to save to, so say what is
  // missing instead of opening a form that cannot succeed.
  if (!store.scoreAwardsReady)
    return showMigrationSetup(context, scoreAwardsMigration);
  final amount = TextEditingController();
  final note = TextEditingController();
  return showFormDialog<void>(
    context: context,
    onDisposed: () {
      amount.dispose();
      note.dispose();
    },
    builder: (dialogContext) => AlertDialog(
      title: Text('${student.name} — ball qo‘shish'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Ball',
                  hintText: 'Masalan: 10 yoki -5',
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: amount,
                builder: (context, value, _) {
                  final points = int.tryParse(value.text.trim());
                  if (points == null || points == 0) {
                    return const Text(
                      'Minus bilan yozilsa jarima bo‘ladi.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    );
                  }
                  return Row(
                    children: [
                      _SignedPoints(points),
                      const SizedBox(width: 8),
                      Text(
                        points > 0 ? 'rag‘bat' : 'jarima',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: points > 0
                              ? AppColors.rewardGreen
                              : AppColors.penaltyRed,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Izoh',
                  hintText: 'Nima uchun berilayotgani',
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
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: amount,
          builder: (context, value, _) {
            final points = int.tryParse(value.text.trim()) ?? 0;
            return FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: points < 0
                    ? AppColors.penaltyRed
                    : AppColors.rewardGreen,
              ),
              onPressed: points == 0
                  ? null
                  : () async {
                      Navigator.pop(dialogContext);
                      await runCrmAction(
                        context,
                        () => store.addScoreAward(
                          studentId: student.id,
                          groupId: group.id,
                          amount: points,
                          note: note.text.trim(),
                        ),
                        success: 'Ball saqlandi',
                      );
                    },
              child: const Text('Saqlash'),
            );
          },
        ),
      ],
    ),
  );
}

/// The awards table has to exist before points can be handed out. Rather
/// than a button that does nothing, say which migration is missing.
