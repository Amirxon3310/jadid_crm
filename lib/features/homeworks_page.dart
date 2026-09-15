import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import 'group_page.dart';

class HomeworksPage extends StatelessWidget {
  const HomeworksPage({super.key, required this.store});

  final CrmStore store;

  @override
  Widget build(BuildContext context) {
    final groupIds = store.visibleGroups.map((group) => group.id).toSet();
    final homeworks = store.homeworks
        .where((homework) => groupIds.contains(homework.groupId))
        .toList();

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
            Builder(
              builder: (context) {
                final group = store.groupById(homework.groupId);
                final waiting = store.studentsOf(group.id).where((student) {
                  return store.resultFor(homework.id, student.id).status ==
                      HomeworkStatus.submitted;
                }).length;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 7),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.softBlue(context),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  title: Text(
                    homework.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${group.name} • muddat ${shortDate(homework.dueDate)}',
                  ),
                  trailing: store.activeRole == AppRole.student
                      ? _StudentStatus(store: store, homework: homework)
                      : Chip(label: Text('$waiting ta tekshiriladi')),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GroupPage(store: store, group: group, startTab: 2),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StudentStatus extends StatelessWidget {
  const _StudentStatus({required this.store, required this.homework});

  final CrmStore store;
  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final result = store.resultFor(homework.id, store.activeUser.id);
    final (text, color) = switch (result.status) {
      HomeworkStatus.waiting => ('Bajarilmagan', AppColors.muted),
      HomeworkStatus.submitted => ('Tekshirilmoqda', AppColors.warning),
      HomeworkStatus.accepted => ('Qabul qilindi', AppColors.rewardGreen),
      HomeworkStatus.returned => ('Qaytarildi', AppColors.danger),
    };
    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
