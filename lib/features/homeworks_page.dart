import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../core/navigation.dart';
import '../data/models.dart';
import 'homework_pages.dart';

class HomeworksPage extends StatelessWidget {
  const HomeworksPage({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final groupIds = store.visibleGroups.map((group) => group.id).toSet();
    final homeworks =
        store.homeworks
            .where((homework) => groupIds.contains(homework.groupId))
            .toList()
          // Newest deadline first: that is the one still being worked on.
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            store.activeRole == AppRole.student
                ? 'Mening uy vazifalarim'
                : 'Uy vazifalari va tekshiruv',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          if (homeworks.isEmpty)
            const EmptyState(
              text: 'Uy vazifasi yo‘q',
              icon: Icons.assignment_outlined,
            ),
          for (final homework in homeworks)
            _HomeworkRow(store: store, homework: homework),
        ],
      ),
    );
  }
}

class _HomeworkRow extends StatelessWidget {
  const _HomeworkRow({required this.store, required this.homework});

  final CrmStore store;
  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final group = store.groupById(homework.groupId);
    final lesson = store.lessons
        .where((l) => l.id == homework.lessonId)
        .firstOrNull;
    final student = store.activeRole == AppRole.student;
    final status = student
        ? store.resultFor(homework.id, store.activeUser.id).status
        : null;
    final color = status == null
        ? AppColors.primary
        : homeworkStatusColor(status);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 7),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(Icons.assignment_outlined, color: color),
      ),
      title: Text(
        homework.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Tag(Icons.layers_outlined, group.name),
            _Tag(
              Icons.event_outlined,
              lesson == null
                  ? 'Muddat ${shortDate(homework.dueDate)}'
                  : '${shortDate(lesson.startsAt)} darsi',
            ),
            if (student)
              _Tag(Icons.circle, homeworkStatusLabel(status!), color: color)
            else
              ..._teacherTags(),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: () => goTo(
        context,
        homeworkPath(homework.id),
        fallback: (_) =>
            HomeworkDetailPage(store: store, homeworkId: homework.id),
      ),
    );
  }

  /// Staff see the group's split at a glance: accepted, waiting to be
  /// marked, and still not handed in.
  List<Widget> _teacherTags() {
    final students = store.studentsOf(homework.groupId);
    var done = 0, waiting = 0, missing = 0;
    for (final student in students) {
      switch (store.resultFor(homework.id, student.id).status) {
        case HomeworkStatus.accepted:
          done++;
        case HomeworkStatus.submitted:
          waiting++;
        case HomeworkStatus.waiting:
        case HomeworkStatus.returned:
          missing++;
      }
    }
    return [
      _Tag(Icons.check_circle, '$done bajardi', color: AppColors.rewardGreen),
      if (waiting > 0)
        _Tag(
          Icons.hourglass_bottom_rounded,
          '$waiting tekshiriladi',
          color: AppColors.warning,
        ),
      if (missing > 0)
        _Tag(
          Icons.cancel_rounded,
          '$missing bajarmadi',
          color: AppColors.penaltyRed,
        ),
    ];
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.label, {this.color = AppColors.muted});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
