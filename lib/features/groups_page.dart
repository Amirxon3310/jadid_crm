import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../data/crm_store.dart';
import '../core/navigation.dart';
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
  (null, 'Barcha holatlar'),
  ('active', 'Faol'),
  ('completed', 'Tugatilgan'),
  ('frozen', 'Muzlatilgan'),
];

/// How the list is ordered. Every option but the name sorts high-to-low, so
/// the group that is doing best is on top.
enum _GroupSort {
  name('Nomi bo‘yicha', Icons.sort_by_alpha_rounded),
  points('Ball bo‘yicha', Icons.star_rounded),
  attendance('Davomat bo‘yicha', Icons.event_available_outlined),
  homework('Uy vazifa bo‘yicha', Icons.assignment_turned_in_outlined);

  const _GroupSort(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _GroupsPageState extends State<GroupsPage> {
  String query = '';
  String? statusFilter;
  String? teacherFilter;
  _GroupSort sort = _GroupSort.name;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final teachers = <String, String>{
      for (final group in store.visibleGroups)
        if (group.teacherId.isNotEmpty) group.teacherId: group.teacherName,
    };
    if (teacherFilter != null && !teachers.containsKey(teacherFilter))
      teacherFilter = null;
    final groups = store.visibleGroups.where((group) {
      final matchesQuery = '${group.name} ${group.course} ${group.teacherName}'
          .toLowerCase()
          .contains(query.toLowerCase());
      return matchesQuery &&
          (statusFilter == null || group.status == statusFilter) &&
          (teacherFilter == null || group.teacherId == teacherFilter);
    }).toList();
    // A group with nothing to measure sorts last rather than as a zero.
    double rank(StudyGroup group) => switch (sort) {
      _GroupSort.name => 0,
      _GroupSort.points => store.groupPointTotal(group.id).toDouble(),
      _GroupSort.attendance => store.groupAttendanceRate(group.id) ?? -1,
      _GroupSort.homework => store.groupHomeworkRate(group.id) ?? -1,
    };
    groups.sort(
      (a, b) => sort == _GroupSort.name
          ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
          : rank(b).compareTo(rank(a)),
    );

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
            spacing: 12,
            runSpacing: 12,
            children: [
              _FilterMenu<String?>(
                label: 'Holat',
                icon: Icons.filter_alt_outlined,
                value: statusFilter,
                items: [
                  for (final (value, label) in _statusFilters)
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: (value) => setState(() => statusFilter = value),
              ),
              _FilterMenu<String?>(
                label: 'Ustoz',
                icon: Icons.school_outlined,
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
              _FilterMenu<_GroupSort>(
                label: 'Tartib',
                icon: sort.icon,
                value: sort,
                items: [
                  for (final option in _GroupSort.values)
                    DropdownMenuItem(value: option, child: Text(option.label)),
                ],
                onChanged: (value) => setState(() => sort = value),
              ),
            ],
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

  void _addGroup(BuildContext context) =>
      goOr(context, '/groups/new', () => editStudyGroup(context, widget.store));
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.store, required this.group});

  final CrmStore store;
  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final attendance = store.groupAttendanceRate(group.id);
    final homework = store.groupHomeworkRate(group.id);
    final points = store.groupPointTotal(group.id);
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
                    group.active ? Icons.check_circle : Icons.cancel_outlined,
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
                      onPressed: () => goOr(
                        context,
                        '${groupPath(group.id)}/edit',
                        () => editStudyGroup(context, store, group: group),
                      ),
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
                    color: _rateColor(attendance),
                  ),
                  _StatPill(
                    icon: Icons.assignment_turned_in_outlined,
                    label: homework == null
                        ? 'Uy vazifa —'
                        : 'Uy vazifa ${homework.round()}%',
                    color: _rateColor(homework),
                  ),
                  _StatPill(
                    icon: Icons.star_rounded,
                    label: '$points ball',
                    color: points < 0
                        ? AppColors.penaltyRed
                        : points == 0
                        ? AppColors.muted
                        : AppColors.rewardGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) => goTo(
    context,
    groupPath(group.id),
    fallback: (_) => GroupPage(store: store, group: group),
  );
}

/// Green once a group is keeping up, red when it has fallen behind, muted
/// while there is nothing to judge it on yet.
Color _rateColor(double? rate) => rate == null
    ? AppColors.muted
    : rate >= _goodRate
    ? AppColors.rewardGreen
    : AppColors.penaltyRed;

const _goodRate = 70.0;

/// A rounded pill that opens a menu — the filters and the sort order sit in
/// these rather than in a row of chips.
class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
      ),
      items: items,
      // A nullable T accepts the "all" entry; a non-nullable one never
      // reports null in the first place.
      onChanged: (next) {
        if (next is T) onChanged(next);
      },
    ),
  );
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
