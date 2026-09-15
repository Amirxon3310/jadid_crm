import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import 'dashboard_page.dart';
import 'groups_page.dart';
import 'homeworks_page.dart';
import 'people_page.dart';
import 'profile_page.dart';
import 'student_dashboard_page.dart';
import 'teacher_dashboard_page.dart';
import 'payments_page.dart';
import 'branches_page.dart';
import '../core/user_avatar.dart';

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.store});
  final CrmStore store;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  int selectedPage = 0;
  bool collapsed = false;
  String? profileUserId;
  void _showProfile(String id) => setState(() => profileUserId = id);
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
    widget.store.startLiveUpdates();
  }

  @override
  void didUpdateWidget(covariant Workspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_refresh);
      widget.store.addListener(_refresh);
      widget.store.startLiveUpdates();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1000;
    final menu = _menu();
    if (selectedPage >= menu.length) selectedPage = 0;
    final current = menu[selectedPage];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        automaticallyImplyLeading: false,
        leading: wide
            ? null
            : Builder(
                builder: (context) => IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).openAppDrawerTooltip,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const AppIcon('menu', size: 24),
                ),
              ),
        actions: [
          IconButton(
            tooltip: dark ? 'Yorug‘ rejim' : 'Tungi rejim',
            onPressed: () =>
                appThemeMode.value = dark ? ThemeMode.light : ThemeMode.dark,
            icon: Icon(
              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 34,
            ),
          ),
          const SizedBox(width: 26),
          PopupMenuButton<String>(
            tooltip: 'Profil va sozlamalar',
            offset: const Offset(0, 66),
            constraints: const BoxConstraints.tightFor(width: 290),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            color: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: .14),
            menuPadding: const EdgeInsets.all(12),
            onSelected: (value) {
              if (value == 'profile') _showProfile(widget.store.activeUser.id);
              if (value == 'users')
                showProfiles(context, widget.store, onSelected: _showProfile);
              if (value == 'logout')
                runCrmAction(
                  context,
                  () => widget.store.client!.auth.signOut(),
                );
              if (value == 'homeworks')
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Uy vazifalari')),
                      body: AnimatedBuilder(
                        animation: widget.store,
                        builder: (context, _) => SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: HomeworksPage(store: widget.store),
                        ),
                      ),
                    ),
                  ),
                );
              for (final role in AppRole.values) {
                if (value == role.name && !widget.store.isOnline) {
                  selectedPage = 0;
                  profileUserId = null;
                  widget.store.changeRole(role);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
                child: Row(
                  children: [
                    UserAvatar(
                      store: widget.store,
                      user: widget.store.activeUser,
                      radius: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.store.activeUser.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            switch (widget.store.activeRole) {
                              AppRole.admin => 'Administrator',
                              AppRole.teacher => 'Ustoz',
                              AppRole.student => 'O‘quvchi',
                            },
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              _accountItem(
                'profile',
                'Mening profilim',
                Icons.person_outline_rounded,
              ),
              if (widget.store.activeRole == AppRole.admin)
                _accountItem(
                  'users',
                  'Foydalanuvchilar',
                  Icons.people_outline_rounded,
                ),
              _accountItem(
                'homeworks',
                'Uy vazifalari',
                Icons.assignment_outlined,
              ),
              if (widget.store.isOnline) ...[
                const PopupMenuDivider(height: 12),
                _accountItem(
                  'logout',
                  'Chiqish',
                  Icons.logout_rounded,
                  danger: true,
                ),
              ] else
                ...AppRole.values.map(
                  (role) => PopupMenuItem(
                    value: role.name,
                    child: Text(
                      '${switch (role) {
                        AppRole.admin => 'Admin',
                        AppRole.teacher => 'Ustoz',
                        AppRole.student => 'O‘quvchi',
                      }} • demo',
                    ),
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    store: widget.store,
                    user: widget.store.activeUser,
                    radius: 26,
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: wide ? width * .045 : 20),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _navigation(menu, drawer: true),
                ),
              ),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 38, 0, 38),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: collapsed
                    ? 86
                    : width >= 1400
                    ? 350
                    : 280,
                child: SingleChildScrollView(child: _navigation(menu)),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 38 : 20,
                wide ? 38 : 24,
                wide ? width * .085 : 20,
                38,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profileUserId == null ? current.title : 'Profil',
                    style: const TextStyle(
                      fontSize: 27,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    profileUserId != null
                        ? 'Shaxsiy ma’lumotlar va akkaunt sozlamalari'
                        : selectedPage == 0 &&
                              widget.store.activeRole == AppRole.admin
                        ? 'Platforma statistikasi va ko‘rsatkichlari'
                        : _welcomeText(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (profileUserId != null)
                    ProfilePage(
                      key: ValueKey(profileUserId),
                      store: widget.store,
                      userId: profileUserId!,
                      onCancel: () => setState(() => profileUserId = null),
                    )
                  else
                    current.page,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigation(List<_MenuItem> menu, {bool drawer = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 210 && !drawer;
        return Surface(
          key: const ValueKey('sidebar-navigation'),
          radius: 36,
          padding: compact ? 12 : 26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: compact ? Alignment.center : Alignment.centerRight,
                child: IconButton(
                  key: const ValueKey('sidebar-toggle'),
                  tooltip: collapsed && !drawer
                      ? 'Menyuni kengaytirish'
                      : 'Menyuni yig‘ish',
                  onPressed: drawer
                      ? () => Navigator.pop(context)
                      : () => setState(() => collapsed = !collapsed),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const AppIcon('menu', size: 24),
                ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < menu.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Tooltip(
                    message: compact ? menu[index].title : '',
                    child: Material(
                      color: profileUserId == null && selectedPage == index
                          ? AppColors.softBlue(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            selectedPage = index;
                            profileUserId = null;
                          });
                          if (drawer) Navigator.pop(context);
                        },
                        child: SizedBox(
                          height: 52,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 12 : 16,
                            ),
                            child: Row(
                              mainAxisAlignment: compact
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                AppIcon(
                                  menu[index].asset,
                                  active:
                                      profileUserId == null &&
                                      selectedPage == index,
                                  fallback: menu[index].icon,
                                  size: 27,
                                ),
                                if (!compact) ...[
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      menu[index].title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            profileUserId == null &&
                                                selectedPage == index
                                            ? AppColors.primary
                                            : AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _accountItem(
    String value,
    String title,
    IconData icon, {
    bool danger = false,
  }) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return PopupMenuItem(
      value: value,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: switch (value) {
                'logout' => const AppIcon('exit', active: false, size: 19),
                'profile' => AppIcon(
                  'user',
                  active: profileUserId == widget.store.activeUser.id,
                  size: 20,
                ),
                'users' => const AppIcon('groups', active: true, size: 20),
                _ => Icon(icon, size: 20, color: color),
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: danger ? color : null),
            ),
          ),
        ],
      ),
    );
  }

  List<_MenuItem> _menu() => [
    _MenuItem(
      'Dashboard',
      'dashboards',
      Icons.dashboard_outlined,
      widget.store.activeRole == AppRole.student
          ? StudentDashboardPage(store: widget.store)
          : widget.store.activeRole == AppRole.teacher
          ? TeacherDashboardPage(store: widget.store)
          : DashboardPage(store: widget.store, onOpenProfile: _showProfile),
    ),
    _MenuItem(
      widget.store.activeRole == AppRole.student ? 'Guruhlarim' : 'Guruhlar',
      'groups',
      Icons.layers_outlined,
      widget.store.activeRole == AppRole.student
          ? MyGroupsPage(store: widget.store)
          : GroupsPage(store: widget.store),
    ),
    if (widget.store.activeRole == AppRole.admin)
      _MenuItem(
        'Ustozlar',
        'teachers',
        Icons.school_outlined,
        PeoplePage(
          store: widget.store,
          showTeachers: true,
          onOpenProfile: _showProfile,
        ),
      ),
    if (widget.store.activeRole != AppRole.student)
      _MenuItem(
        'O‘quvchilar',
        'students',
        Icons.person_outline,
        PeoplePage(
          store: widget.store,
          showTeachers: false,
          onOpenProfile: _showProfile,
        ),
      ),
    if (widget.store.activeRole != AppRole.teacher)
      _MenuItem(
        'To‘lovlar',
        null,
        Icons.account_balance_wallet_outlined,
        PaymentsPage(store: widget.store),
      ),
    if (widget.store.activeRole == AppRole.admin)
      _MenuItem(
        'Filiallar',
        null,
        Icons.location_on_outlined,
        BranchesPage(store: widget.store),
      ),
    _MenuItem(
      'Uy vazifalari',
      null,
      Icons.assignment_outlined,
      HomeworksPage(store: widget.store),
    ),
  ];

  String _welcomeText() => switch (widget.store.activeRole) {
    AppRole.admin =>
      'Markazdagi ustozlar, o‘quvchilar va guruhlarni boshqaring.',
    AppRole.teacher =>
      'Guruhlaringiz, davomat va vazifalarni bir joyda boshqaring.',
    AppRole.student => 'Dars jadvali, davomat va uy vazifalaringizni kuzating.',
  };
}

class _MenuItem {
  const _MenuItem(this.title, this.asset, this.icon, this.page);
  final String title;
  final String? asset;
  final IconData icon;
  final Widget page;
}
