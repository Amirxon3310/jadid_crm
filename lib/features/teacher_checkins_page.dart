import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/filter_bar.dart';
import '../core/helpers.dart';
import '../core/navigation.dart';
import '../core/user_avatar.dart';
import '../data/crm_store.dart';
import '../data/models.dart';

/// How late a teacher was for the lesson they photographed themselves at.
/// Negative means they were early.
int _lateMinutes(LessonCheckin checkin, Lesson lesson) =>
    checkin.checkedAt.difference(lesson.startsAt).inMinutes;

Color _lateColor(int minutes) => minutes <= 0
    ? AppColors.rewardGreen
    : minutes <= attendanceLeadMinutes
    ? AppColors.warning
    : AppColors.penaltyRed;

String _lateLabel(int minutes) => minutes <= 0
    ? '${minutes == 0 ? 'Vaqtida' : '${-minutes} daqiqa erta'}'
    : '$minutes daqiqa kech';

/// Every selfie a teacher took to open a lesson: who, which group, which
/// lesson, when it should have started and when they actually arrived.
class TeacherCheckinsPage extends StatefulWidget {
  const TeacherCheckinsPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<TeacherCheckinsPage> createState() => _TeacherCheckinsPageState();
}

class _TeacherCheckinsPageState extends State<TeacherCheckinsPage> {
  String? teacherFilter;
  bool lateOnly = false;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lessonById = {for (final lesson in store.lessons) lesson.id: lesson};
    final rows = [
      for (final checkin in store.checkins)
        if (lessonById[checkin.lessonId] != null)
          (checkin: checkin, lesson: lessonById[checkin.lessonId]!),
    ]..sort((a, b) => b.checkin.checkedAt.compareTo(a.checkin.checkedAt));
    final teachers = <String, String>{
      for (final row in rows)
        row.checkin.teacherId:
            store.users
                .where((u) => u.id == row.checkin.teacherId)
                .firstOrNull
                ?.name ??
            'Ustoz',
    };
    if (teacherFilter != null && !teachers.containsKey(teacherFilter)) {
      teacherFilter = null;
    }
    final shown = rows.where((row) {
      if (teacherFilter != null && row.checkin.teacherId != teacherFilter) {
        return false;
      }
      return !lateOnly || _lateMinutes(row.checkin, row.lesson) > 0;
    }).toList();

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ustozlar davomati',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Har bir dars uchun ustoz tushgan surat va kelgan vaqti.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterField<String?>(
                label: 'Ustoz',
                icon: Icons.school_outlined,
                active: teacherFilter != null,
                value: teacherFilter,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Barcha ustozlar'),
                  ),
                  for (final entry in teachers.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => teacherFilter = value),
              ),
              FilterToggle(
                label: 'Faqat kechikkanlar',
                icon: Icons.timer_outlined,
                value: lateOnly,
                onChanged: (value) => setState(() => lateOnly = value),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 26),
                child: ClearFiltersButton(
                  count: [
                    teacherFilter != null,
                    lateOnly,
                  ].where((on) => on).length,
                  onPressed: () => setState(() {
                    teacherFilter = null;
                    lateOnly = false;
                  }),
                ),
              ),
            ],
          ),
          ActiveFilters(
            onClearAll: () => setState(() {
              teacherFilter = null;
              lateOnly = false;
            }),
            filters: [
              if (teacherFilter != null)
                (
                  icon: Icons.school_outlined,
                  label: 'Ustoz',
                  value: teachers[teacherFilter] ?? 'Ustoz',
                  remove: () => setState(() => teacherFilter = null),
                ),
              if (lateOnly)
                (
                  icon: Icons.timer_outlined,
                  label: 'Holat',
                  value: 'Faqat kechikkanlar',
                  remove: () => setState(() => lateOnly = false),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const EmptyState(
              text: 'Hali suratli davomat yo‘q',
              icon: Icons.photo_camera_outlined,
            )
          else
            for (final row in shown)
              _CheckinRow(
                store: store,
                checkin: row.checkin,
                lesson: row.lesson,
              ),
        ],
      ),
    );
  }
}

class _CheckinRow extends StatelessWidget {
  const _CheckinRow({
    required this.store,
    required this.checkin,
    required this.lesson,
  });

  final CrmStore store;
  final LessonCheckin checkin;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final teacher = store.users
        .where((u) => u.id == checkin.teacherId)
        .firstOrNull;
    final group = store.groups.where((g) => g.id == lesson.groupId).firstOrNull;
    final late = _lateMinutes(checkin, lesson);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Photo(store: store, checkin: checkin),
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (teacher != null)
                      UserAvatar(store: store, user: teacher, radius: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: teacher == null
                          ? const Text('Ustoz')
                          : PersonName(userId: teacher.id, name: teacher.name),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  group?.name ?? 'Guruh',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lesson.topic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${shortDate(tashkentDate(lesson.startsAt))} • dars '
                  '${shortTime(tashkentDate(lesson.startsAt))}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rasmga tushdi',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  shortTime(tashkentDate(checkin.checkedAt)),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _lateColor(late).withValues(alpha: .14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _lateColor(late).withValues(alpha: .45),
              ),
            ),
            child: Text(
              _lateLabel(late),
              style: TextStyle(
                color: _lateColor(late),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.store, required this.checkin});

  final CrmStore store;
  final LessonCheckin checkin;

  @override
  Widget build(BuildContext context) {
    final bytes = store.checkinImages[checkin.photoPath];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => runCrmAction(context, () async {
        final url = bytes == null
            ? await store.checkinUrl(checkin.photoPath)
            : null;
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Darsdagi surat'),
            content: SizedBox(
              width: 480,
              child: bytes != null ? Image.memory(bytes) : Image.network(url!),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Yopish'),
              ),
            ],
          ),
        );
      }),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 76,
          height: 76,
          color: AppColors.panel(context),
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover)
              : const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.primary,
                ),
        ),
      ),
    );
  }
}
