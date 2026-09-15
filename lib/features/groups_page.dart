import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import 'group_page.dart';
import 'group_editor.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key, required this.store});

  final CrmStore store;

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

const _statusFilters = [
  (null, 'Hammasi'),
  ('active', 'Faol'),
  ('completed', 'Tugatilgan'),
  ('frozen', 'Muzlatilgan'),
];

class _GroupsPageState extends State<GroupsPage> {
  String query = '';
  String? statusFilter;

  @override
  Widget build(BuildContext context) {
    final groups = widget.store.visibleGroups.where((group) {
      final matchesQuery = '${group.name} ${group.course} ${group.teacherName}'
          .toLowerCase()
          .contains(query.toLowerCase());
      return matchesQuery &&
          (statusFilter == null || group.status == statusFilter);
    }).toList();

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                decoration: const InputDecoration(
                  hintText: 'Guruh, kurs yoki ustozni qidiring',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value),
              );
              final addButton = FilledButton.icon(
                onPressed: () => _addGroup(context),
                icon: const Icon(Icons.add),
                label: const Text('Guruh qo‘shish'),
              );
              if (widget.store.activeRole != AppRole.admin) return search;
              if (constraints.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [search, const SizedBox(height: 10), addButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  addButton,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statusFilters.map((filter) {
              final (value, label) = filter;
              return ChoiceChip(
                label: Text(label),
                selected: statusFilter == value,
                onSelected: (_) => setState(() => statusFilter = value),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const EmptyState(
              text: 'Guruh topilmadi',
              icon: Icons.groups_outlined,
            ),
          for (final group in groups) ...[
            const Divider(height: 1),
            _GroupTile(store: widget.store, group: group),
          ],
        ],
      ),
    );
  }

  Future<void> _addGroup(BuildContext context) =>
      editStudyGroup(context, widget.store);
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final attendance = store.groupAttendanceRate(group.id);
    final homework = store.groupHomeworkRate(group.id);
    final coins = store.groupCoinTotal(group.id);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    group.active
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    color: group.active ? AppColors.success : AppColors.danger,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${group.course} • ${group.teacherName}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (store.activeRole == AppRole.admin)
                    IconButton(
                      tooltip: 'Guruhni tahrirlash',
                      onPressed: () =>
                          editStudyGroup(context, store, group: group),
                      icon: const AppIcon('edit', size: 22),
                    ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _StatPill(
                    icon: Icons.groups_outlined,
                    label: '${store.studentsOf(group.id).length} o‘quvchi',
                  ),
                  _StatPill(
                    icon: Icons.event_available_outlined,
                    label: attendance == null
                        ? 'Davomat —'
                        : 'Davomat ${attendance.round()}%',
                  ),
                  _StatPill(
                    icon: Icons.assignment_turned_in_outlined,
                    label: homework == null
                        ? 'Uy vazifa —'
                        : 'Uy vazifa ${homework.round()}%',
                  ),
                  _StatPill(
                    icon: Icons.emoji_events_outlined,
                    label: '$coins coin',
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GroupPage(store: store, group: group),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    this.color = AppColors.muted,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
