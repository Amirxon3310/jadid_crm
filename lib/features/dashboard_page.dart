import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/filter_bar.dart';
import '../core/app_icon.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../core/navigation.dart';
import '../data/models.dart';
import 'group_page.dart';
import 'profile_page.dart';
import '../core/user_avatar.dart';
import '../data/dashboard_metrics.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.store, this.onOpenProfile});
  final CrmStore store;
  final ValueChanged<String>? onOpenProfile;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String query = '';
  CrmStore get store => widget.store;

  double? _reviewRate(AppUser teacher) {
    final groups = store.groups
        .where((g) => g.teacherId == teacher.id)
        .map((g) => g.id)
        .toSet();
    final assignments = store.homeworks
        .where((h) => groups.contains(h.groupId))
        .map((h) => h.id)
        .toSet();
    final answers = store.results
        .where(
          (r) =>
              assignments.contains(r.homeworkId) &&
              r.status != HomeworkStatus.waiting,
        )
        .toList();
    if (answers.isEmpty) return null;
    return answers
            .where(
              (r) =>
                  r.status == HomeworkStatus.accepted ||
                  r.status == HomeworkStatus.returned,
            )
            .length /
        answers.length;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = store.dashboardMetrics;
    String count(String key) => metrics.value(key).current.toInt().toString();
    final rate = metrics
        .value('success_rate')
        .current
        .toStringAsFixed(1)
        .replaceFirst(RegExp(r'\.0$'), '');
    final cards = [
      (
        count('employees'),
        'Jami xodimlar',
        metrics.value('employees'),
        'teachers',
        Icons.school_outlined,
        AppColors.primary,
      ),
      (
        count('students'),
        'Jami o‘quvchilar',
        metrics.value('students'),
        'students',
        Icons.person_outline_rounded,
        AppColors.primary,
      ),
      (
        count('graduates'),
        'Bitirgan o‘quvchilar',
        metrics.value('graduates'),
        null,
        Icons.school_outlined,
        AppColors.success,
      ),
      (
        '$rate%',
        'Muvaffaqiyatli bitirganlar foizi',
        metrics.value('success_rate'),
        null,
        Icons.star_border_rounded,
        AppColors.danger,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 800
                ? 4
                : constraints.maxWidth >= 460
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 22) / columns;
            return Wrap(
              spacing: 22,
              runSpacing: 22,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width: width,
                      child: Surface(
                        padding: 15,
                        radius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: card.$6.withValues(alpha: .19),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Center(
                                    child: card.$4 != null
                                        ? AppIcon(
                                            card.$4,
                                            active: true,
                                            size: 24,
                                          )
                                        : Icon(
                                            card.$5,
                                            color: card.$6,
                                            size: 27,
                                          ),
                                  ),
                                ),
                                Flexible(
                                  child: MetricGrowthBadge(metric: card.$3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              card.$1,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              card.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 34),
        if (store.activeRole == AppRole.admin)
          _teachers(context)
        else
          _lessons(context),
      ],
    );
  }

  Widget _teachers(BuildContext context) {
    final teachers =
        store.teachers
            .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
            .toList()
          ..sort(
            (a, b) => (_reviewRate(b) ?? -1).compareTo(_reviewRate(a) ?? -1),
          );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 540),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 34, 26, 34),
                child: LayoutBuilder(
                  builder: (context, c) {
                    const title = Text(
                      'Top ustozlar',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.7,
                      ),
                    );
                    final search = SizedBox(
                      width: c.maxWidth < 560 ? c.maxWidth : 340,
                      child: FilterSearch(
                        hint: 'Nomi bo‘yicha qidiruv',
                        onChanged: (value) => setState(() => query = value),
                      ),
                    );
                    return c.maxWidth < 560
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              const SizedBox(height: 18),
                              search,
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: title),
                              const SizedBox(width: 16),
                              search,
                            ],
                          );
                  },
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: constraints.maxWidth < 960
                        ? 960
                        : constraints.maxWidth,
                    child: Column(
                      children: [
                        Container(
                          color: dark
                              ? const Color(0xFF293344)
                              : const Color(0xFFF1F1F1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 12,
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                flex: 36,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 42),
                                  child: Text(
                                    'Foydalanuvchi ismi',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 13,
                                child: Text(
                                  'Role',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                              Expanded(
                                flex: 23,
                                child: Text(
                                  'Ro‘yxatdan o‘tgan\nsana',
                                  style: TextStyle(fontSize: 15, height: 1.2),
                                ),
                              ),
                              Expanded(
                                flex: 17,
                                child: Text(
                                  'Tekshirgan',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                              Expanded(
                                flex: 11,
                                child: Text(
                                  'Amallar',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (teachers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 64),
                            child: EmptyState(
                              text: query.isEmpty
                                  ? 'Ustozlar hali ro‘yxatdan o‘tmagan'
                                  : 'Ustoz topilmadi',
                              icon: Icons.school_outlined,
                            ),
                          ),
                        for (final teacher in teachers)
                          _teacherRow(context, teacher),
                        if (teachers.isNotEmpty) const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teacherRow(BuildContext context, AppUser teacher) {
    final rate = _reviewRate(teacher);
    final hasGroups = store.groups.any((g) => g.teacherId == teacher.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 12, 36, 7),
      child: Row(
        children: [
          Expanded(
            flex: 36,
            child: Row(
              children: [
                const SizedBox(width: 40),
                UserAvatar(store: store, user: teacher, radius: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher.phone.isEmpty
                            ? 'Telefon kiritilmagan'
                            : teacher.phone,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          const Expanded(
            flex: 13,
            child: Text('Ustoz', style: TextStyle(fontSize: 17)),
          ),
          Expanded(
            flex: 23,
            child: Text(
              teacher.createdAt == null ? '—' : shortDate(teacher.createdAt!),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 17,
            child: Row(
              children: [
                SizedBox(
                  width: 33,
                  height: 33,
                  child: CircularProgressIndicator(
                    value: rate ?? 0,
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    color: AppColors.success,
                    backgroundColor: AppColors.border,
                    semanticsLabel: 'Tekshirilgan javoblar',
                    semanticsValue: '${((rate ?? 0) * 100).round()}',
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  rate == null ? '—' : '${(rate * 100).round()}%',
                  style: const TextStyle(fontSize: 17),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 11,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Ustoz ma’lumotlari',
                  onPressed: () => widget.onOpenProfile != null
                      ? widget.onOpenProfile!(teacher.id)
                      : openProfile(context, store, teacher.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 44,
                  ),
                  icon: const AppIcon('edit', size: 25),
                ),
                IconButton(
                  tooltip: hasGroups
                      ? 'Avval ustozning guruhlarini boshqa ustozga biriktiring'
                      : 'Ustoz rolini olib tashlash',
                  onPressed: hasGroups
                      ? null
                      : () => _removeTeacherRole(context, teacher),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 44,
                  ),
                  icon: Opacity(
                    opacity: hasGroups ? .4 : 1,
                    child: const AppIcon('delete', size: 27),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeTeacherRole(BuildContext context, AppUser teacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ustoz rolini olib tashlash'),
        content: Text(
          '${teacher.name} o‘quvchi roliga o‘tkaziladi. Akkaunt saqlanadi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tasdiqlash'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted)
      await runCrmAction(
        context,
        () => store.setRole(teacher.id, AppRole.student),
        success: 'Ustoz roli olib tashlandi',
      );
  }

  Widget _lessons(BuildContext context) {
    final now = DateTime.now();
    final lessons = store.visibleGroups
        .expand((g) => store.lessonsOf(g.id))
        .where(
          (l) =>
              l.startsAt.year == now.year &&
              l.startsAt.month == now.month &&
              l.startsAt.day == now.day,
        )
        .toList();
    return Surface(
      radius: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bugungi darslar',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          if (lessons.isEmpty)
            const EmptyState(
              text: 'Bugun dars yo‘q',
              icon: Icons.event_available_outlined,
            ),
          for (final lesson in lessons)
            ListTile(
              leading: const AppIcon('groups', active: true),
              title: Text(lesson.topic),
              subtitle: Text(
                '${store.groupById(lesson.groupId).name} • ${shortTime(lesson.startsAt)}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => goTo(
                context,
                groupPath(lesson.groupId),
                fallback: (_) => GroupPage(
                  store: store,
                  group: store.groupById(lesson.groupId),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MetricGrowthBadge extends StatelessWidget {
  const MetricGrowthBadge({super.key, required this.metric});
  final MetricValue metric;
  @override
  Widget build(BuildContext context) {
    final color = (metric.growth ?? 0) < 0
        ? AppColors.danger
        : (metric.growth ?? 0) > 0 || metric.isNew
        ? AppColors.success
        : AppColors.muted;
    return Tooltip(
      message: metric.explanation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          metric.growthLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
