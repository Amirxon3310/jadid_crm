import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../data/crm_store.dart';
import '../core/navigation.dart';
import '../data/models.dart';
import 'group_page.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key, required this.store});
  final CrmStore store;
  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  String? selectedGroup;
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final groups = List<StudyGroup>.of(store.visibleGroups)
      ..sort(
        (a, b) =>
            (store.studentById(store.activeUser.id, a.id).completed ? 1 : 0)
                .compareTo(
                  store.studentById(store.activeUser.id, b.id).completed
                      ? 1
                      : 0,
                ),
      );
    // No picker any more: the cards below carry each group's own progress.
    final selected = groups.firstOrNull;
    final progress = selected == null ? null : store.progressFor(selected.id);
    String rank(int? value) => value == null ? '—' : '$value-o‘rin';
    final cards = [
      (
        '${store.pointsOf(store.activeUser.id)}',
        'Jami ballar',
        Icons.star_rounded,
        AppColors.rewardGreen,
        'Davomat uchun 10 ball va qabul qilingan vazifalar baholari',
      ),
      (
        rank(selected == null ? null : store.rankFor(groupId: selected.id)),
        'Guruhdagi o‘rningiz',
        Icons.people_outline,
        AppColors.primary,
        'Guruh ichida jami ball bo‘yicha; teng ball — teng o‘rin',
      ),
      (
        rank(store.rankFor()),
        'Markazdagi o‘rningiz',
        Icons.emoji_events_outlined,
        AppColors.success,
        'Markazdagi jami ball bo‘yicha reyting',
      ),
      (
        progress?.label ?? '—',
        'Kursni tugatish',
        Icons.donut_large_rounded,
        AppColors.primary,
        progress == null || progress.total == 0
            ? 'Hali darslar rejalashtirilmagan'
            : '${progress.completed} / ${progress.total} dars o‘tilgan',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 820
                ? 4
                : c.maxWidth >= 460
                ? 2
                : 1;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width: (c.maxWidth - (columns - 1) * 20) / columns,
                      child: Tooltip(
                        message: card.$5,
                        child: Surface(
                          radius: 22,
                          padding: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: card.$4.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(card.$3, color: card.$4, size: 26),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                card.$1,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                card.$2,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 28),
        MyGroupsPage(store: store),
      ],
    );
  }
}

class MyGroupsPage extends StatefulWidget {
  const MyGroupsPage({super.key, required this.store});
  final CrmStore store;
  @override
  State<MyGroupsPage> createState() => _MyGroupsPageState();
}

class _MyGroupsPageState extends State<MyGroupsPage> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final groups = store.visibleGroups.where((g) {
      final enrollment = store.studentById(store.activeUser.id, g.id);
      return filter == 0 ||
          (filter == 1
              ? enrollment.active && g.active
              : filter == 2
              ? enrollment.completed
              : enrollment.left);
    }).toList();
    return Surface(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guruhlarim',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 4; i++)
                ChoiceChip(
                  label: Text(['Barchasi', 'Aktiv', 'Tugatgan', 'Ketgan'][i]),
                  selected: filter == i,
                  onSelected: (_) => setState(() => filter = i),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (groups.isEmpty)
            const EmptyState(
              text: 'Bu ro‘yxatda guruh yo‘q',
              icon: Icons.groups_outlined,
            ),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: StudentGroupCard(store: store, group: group),
            ),
        ],
      ),
    );
  }
}

class StudentGroupCard extends StatelessWidget {
  const StudentGroupCard({super.key, required this.store, required this.group});
  final CrmStore store;
  final StudyGroup group;
  @override
  Widget build(BuildContext context) {
    final enrollment = store.studentById(store.activeUser.id, group.id);
    final done = enrollment.completed;
    final progress = store.progressFor(group.id);
    final color = done ? AppColors.success : AppColors.primary;
    return Material(
      color: color.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => goTo(
          context,
          groupPath(group.id),
          fallback: (_) => GroupPage(store: store, group: group),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppIcon('groups', active: true, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      enrollment.left
                          ? 'Ketgan'
                          : done
                          ? 'Tugatgan'
                          : group.statusLabel,
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${group.course} • ${group.teacherName}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: .10),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                progress.total == 0
                    ? 'Darslar hali rejalashtirilmagan'
                    : '${progress.completed} / ${progress.total} dars • ${progress.label}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
