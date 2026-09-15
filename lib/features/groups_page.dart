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

class _GroupsPageState extends State<GroupsPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final groups = widget.store.visibleGroups.where((group) {
      return '${group.name} ${group.course} ${group.teacherName}'
          .toLowerCase()
          .contains(query.toLowerCase());
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
          const SizedBox(height: 20),
          if (groups.isEmpty)
            const EmptyState(
              text: 'Guruh topilmadi',
              icon: Icons.groups_outlined,
            ),
          for (final group in groups)
            _GroupTile(store: widget.store, group: group),
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const AppIcon('groups', active: true),
            ),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 12,
                    runSpacing: 5,
                    children: [
                      Text(
                        '${group.course} • ${group.statusLabel}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      Text(
                        '${store.studentsOf(group.id).length} o‘quvchi',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      InkWell(
                        onTap: () => _open(context),
                        child: Text(
                          group.teacherName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (store.activeRole == AppRole.admin)
              IconButton(
                tooltip: 'Guruhni tahrirlash',
                onPressed: () => editStudyGroup(context, store, group: group),
                icon: const AppIcon('edit', size: 22),
              ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
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
