import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/navigation.dart';
import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../core/app_icon.dart';
import '../core/helpers.dart';
import '../data/crm_store.dart';
import '../data/models.dart';
import 'profile_page.dart';
import '../core/user_avatar.dart';

/// The sidebar and top bar every routed page sits inside. Which item is
/// lit, and the heading above the page, both come from the current address.
class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key, required this.store, required this.child});
  final CrmStore store;
  final Widget child;
  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  bool collapsed = false;
  void _showProfile(String id) => goTo(context, profilePath(id));
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
    widget.store.startLiveUpdates();
  }

  @override
  void didUpdateWidget(covariant WorkspaceShell oldWidget) {
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
    final location = GoRouterState.of(context).uri.path;
    final onProfile = location.startsWith('/profile');
    // The deepest matching path wins, so /groups/12 still lights "Guruhlar".
    var selectedPage = -1;
    for (var index = 0; index < menu.length; index++) {
      final path = menu[index].path;
      final matches = path == '/'
          ? location == '/'
          : location == path || location.startsWith('$path/');
      if (matches &&
          (selectedPage < 0 || path.length > menu[selectedPage].path.length)) {
        selectedPage = index;
      }
    }
    if (onProfile) selectedPage = -1;
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
            onPressed: () => unawaited(
              setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
            ),
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
              if (value == 'homeworks') goTo(context, '/homeworks');
              for (final role in AppRole.values) {
                if (value == role.name && !widget.store.isOnline) {
                  widget.store.changeRole(role);
                  goTo(context, '/');
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
                  child: _navigation(menu, selectedPage, drawer: true),
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
                child: SingleChildScrollView(
                  child: _navigation(menu, selectedPage),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 38 : 20,
                    wide ? 38 : 24,
                    wide ? width * .085 : 20,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        onProfile
                            ? 'Profil'
                            : selectedPage < 0
                            ? AppConfig.appTitle
                            : menu[selectedPage].title,
                        style: const TextStyle(
                          fontSize: 27,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        onProfile
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigation(
    List<_MenuItem> menu,
    int selectedPage, {
    bool drawer = false,
  }) {
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
                      color: selectedPage == index
                          ? AppColors.softBlue(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          goTo(context, menu[index].path);
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
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AppIcon(
                                      menu[index].asset,
                                      active: selectedPage == index,
                                      fallback: menu[index].icon,
                                      size: 27,
                                    ),
                                    if (menu[index].badge > 0)
                                      Positioned(
                                        top: -6,
                                        right: -9,
                                        child: _MenuBadge(menu[index].badge),
                                      ),
                                  ],
                                ),
                                if (!compact) ...[
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      menu[index].title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: selectedPage == index
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
                'profile' => const AppIcon('user', size: 20),
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
    _MenuItem('Dashboard', 'dashboards', Icons.dashboard_outlined, '/'),
    _MenuItem(
      widget.store.activeRole == AppRole.student ? 'Guruhlarim' : 'Guruhlar',
      'groups',
      Icons.layers_outlined,
      '/groups',
    ),
    if (widget.store.activeRole == AppRole.admin)
      _MenuItem('Ustozlar', 'teachers', Icons.school_outlined, '/teachers'),
    if (widget.store.activeRole != AppRole.student)
      _MenuItem('O‘quvchilar', 'students', Icons.person_outline, '/students'),
    if (widget.store.activeRole != AppRole.teacher)
      _MenuItem(
        'To‘lovlar',
        null,
        Icons.account_balance_wallet_outlined,
        '/payments',
      ),
    if (widget.store.activeRole == AppRole.admin)
      _MenuItem('Filiallar', null, Icons.location_on_outlined, '/branches'),
    if (widget.store.activeRole == AppRole.admin)
      _MenuItem(
        'Ustozlar davomati',
        null,
        Icons.photo_camera_outlined,
        '/checkins',
      ),
    _MenuItem(
      'Uy vazifalari',
      null,
      Icons.assignment_outlined,
      '/homeworks',
      // A pupil sees what they still owe; staff see what is waiting to be
      // marked.
      badge: widget.store.homeworkBadgeCount(),
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
  const _MenuItem(
    this.title,
    this.asset,
    this.icon,
    this.path, {
    this.badge = 0,
  });
  final String title;
  final String? asset;
  final IconData icon;

  /// Where the item goes, and what lights it up when the app is there.
  final String path;

  /// Count shown in a red badge on the menu row; 0 shows nothing.
  final int badge;
}

/// The red count that rides on a menu row's icon.
class _MenuBadge extends StatelessWidget {
  const _MenuBadge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 19),
    height: 19,
    padding: const EdgeInsets.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: AppColors.penaltyRed,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: Theme.of(context).colorScheme.surface,
        width: 2,
      ),
    ),
    alignment: Alignment.center,
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The padding a page inside the shell gives itself. The shell only owns the
/// heading now; each page scrolls on its own, because the routed child is a
/// navigator and cannot sit inside a scroll view.
EdgeInsets workspaceContentPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final wide = width >= 1000;
  return EdgeInsets.fromLTRB(wide ? 38 : 20, 0, wide ? width * .085 : 20, 38);
}
