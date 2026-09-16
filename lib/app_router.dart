import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation.dart';
import 'data/crm_store.dart';
import 'data/models.dart';
import 'features/branches_page.dart';
import 'features/dashboard_page.dart';
import 'features/group_editor.dart';
import 'features/group_page.dart';
import 'features/groups_page.dart';
import 'features/homework_pages.dart';
import 'features/homeworks_page.dart';
import 'features/payments_page.dart';
import 'features/people_page.dart';
import 'features/profile_page.dart';
import 'features/student_dashboard_page.dart';
import 'features/teacher_checkins_page.dart';
import 'features/teacher_dashboard_page.dart';
import 'features/workspace.dart';

/// Every screen has an address. The sidebar, a pasted link and the browser's
/// back button all go through this one table.
GoRouter buildRouter(CrmStore store, {String initialLocation = '/'}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        // The pages that live inside the sidebar chrome.
        ShellRoute(
          builder: (context, state, child) =>
              WorkspaceShell(store: store, child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  _page(context, switch (store.activeRole) {
                    AppRole.student => StudentDashboardPage(store: store),
                    AppRole.teacher => TeacherDashboardPage(store: store),
                    AppRole.admin => DashboardPage(store: store),
                  }),
            ),
            GoRoute(
              path: '/groups',
              builder: (context, state) => _page(
                context,
                store.activeRole == AppRole.student
                    ? MyGroupsPage(store: store)
                    : GroupsPage(store: store),
              ),
            ),
            GoRoute(
              path: '/teachers',
              builder: (context, state) =>
                  _page(context, PeoplePage(store: store, showTeachers: true)),
            ),
            GoRoute(
              path: '/students',
              builder: (context, state) =>
                  _page(context, PeoplePage(store: store, showTeachers: false)),
            ),
            GoRoute(
              path: '/payments',
              builder: (context, state) =>
                  _page(context, PaymentsPage(store: store)),
            ),
            GoRoute(
              path: '/branches',
              builder: (context, state) =>
                  _page(context, BranchesPage(store: store)),
            ),
            GoRoute(
              path: '/checkins',
              builder: (context, state) =>
                  _page(context, TeacherCheckinsPage(store: store)),
            ),
            GoRoute(
              path: '/homeworks',
              builder: (context, state) =>
                  _page(context, HomeworksPage(store: store)),
            ),
            // A person's own page: /profile is yours, /profile/<id> is theirs.
            // The key is what makes the form reload for a different person
            // instead of keeping the last one's answers.
            GoRoute(
              path: '/profile',
              builder: (context, state) => _page(
                context,
                ProfilePage(
                  key: ValueKey(store.activeUser.id),
                  store: store,
                  userId: store.activeUser.id,
                ),
              ),
            ),
            GoRoute(
              path: '/profile/:userId',
              builder: (context, state) => _page(
                context,
                ProfilePage(
                  key: ValueKey(state.pathParameters['userId']),
                  store: store,
                  userId: state.pathParameters['userId']!,
                ),
              ),
            ),
          ],
        ),
        // A new group opens its form over the list.
        GoRoute(
          path: '/groups/new',
          builder: (context, state) => _GroupForm(store: store),
        ),
        GoRoute(
          path: '/groups/:id',
          builder: (context, state) =>
              _group(store, state.pathParameters['id']!, 0),
          routes: [
            // Before the tab route, so "edit" is never read as a tab name.
            GoRoute(
              path: 'edit',
              builder: (context, state) =>
                  _GroupForm(store: store, groupId: state.pathParameters['id']),
            ),
            GoRoute(
              path: ':tab',
              builder: (context, state) => _group(
                store,
                state.pathParameters['id']!,
                groupTabs.indexOf(state.pathParameters['tab'] ?? ''),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/homeworks/:id',
          builder: (context, state) => HomeworkDetailPage(
            store: store,
            homeworkId: state.pathParameters['id']!,
          ),
        ),
      ],
      errorBuilder: (context, state) =>
          _NotFound(location: state.uri.toString()),
    );

/// A page inside the shell: it scrolls itself, under the shell's heading.
Widget _page(BuildContext context, Widget child) => SingleChildScrollView(
  padding: workspaceContentPadding(context),
  child: child,
);

Widget _group(CrmStore store, String groupId, int tab) {
  final group = store.groups
      .where((g) => g.id == store.resolveId(groupId))
      .firstOrNull;
  if (group == null) return const _NotFound(location: 'Guruh');
  return GroupPage(store: store, group: group, startTab: tab < 0 ? 0 : tab);
}

/// The group form is a dialog over the page it belongs to, so that closing it
/// leaves the address back where it came from.
class _GroupForm extends StatefulWidget {
  const _GroupForm({required this.store, this.groupId});
  final CrmStore store;
  final String? groupId;

  @override
  State<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<_GroupForm> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final group = widget.groupId == null
        ? null
        : widget.store.groups
              .where((g) => g.id == widget.store.resolveId(widget.groupId!))
              .firstOrNull;
    await editStudyGroup(context, widget.store, group: group);
    if (!mounted) return;
    goTo(
      context,
      widget.groupId == null ? '/groups' : groupPath(widget.groupId!),
    );
  }

  @override
  Widget build(BuildContext context) => widget.groupId == null
      ? WorkspaceShell(
          store: widget.store,
          child: GroupsPage(store: widget.store),
        )
      : _group(widget.store, widget.groupId!, 0);
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.explore_off_outlined, size: 44),
          const SizedBox(height: 12),
          Text('$location topilmadi.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => goTo(context, '/'),
            child: const Text('Bosh sahifaga'),
          ),
        ],
      ),
    ),
  );
}
