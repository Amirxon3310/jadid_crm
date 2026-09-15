import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../data/crm_store.dart';
import 'groups_page.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key, required this.store});
  final CrmStore store;
  @override
  Widget build(BuildContext context) {
    final metrics = store.teacherMetrics;
    final cards = [
      (
        '${metrics.groups}',
        'Jami guruhlar',
        Icons.groups_outlined,
        AppColors.primary,
      ),
      (
        '${metrics.students}',
        'Jami o‘quvchilar',
        Icons.school_outlined,
        AppColors.primary,
      ),
      (
        '${metrics.left}',
        'Ketgan o‘quvchilar',
        Icons.person_off_outlined,
        AppColors.danger,
      ),
      (
        '${metrics.percent.toStringAsFixed(metrics.percent % 1 == 0 ? 0 : 1)}%',
        'Bitirgan o‘quvchilar',
        Icons.verified_outlined,
        AppColors.success,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 850
                ? 4
                : c.maxWidth >= 450
                ? 2
                : 1;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width: (c.maxWidth - (columns - 1) * 20) / columns,
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
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              card.$2,
                              style: const TextStyle(color: AppColors.muted),
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
        const SizedBox(height: 12),
        Text(
          '${metrics.graduates} / ${metrics.students} o‘quvchi kamida bitta guruhni bitirgan. Har bir o‘quvchi bir marta sanaladi.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 26),
        const Text(
          'Mening guruhlarim',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        GroupsPage(store: store),
      ],
    );
  }
}
