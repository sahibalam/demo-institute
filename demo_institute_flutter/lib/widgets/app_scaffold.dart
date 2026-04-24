import 'package:flutter/material.dart';

import '../routes.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final currentIndex = _bottomIndexForRoute(currentRoute);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        ),
        automaticallyImplyLeading: false,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.92),
                  border: Border.all(color: AppTheme.canvas.withValues(alpha: 0.55), width: 1.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Image.asset(
                      'assets/appicon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(title),
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.94),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Image.asset(
                            'assets/appicon.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DEMO INSTITUTE',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Learning Dashboard',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  'MAIN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                ),
              ),
              _drawerTile(
                context,
                selected: currentRoute == AppRoutes.home,
                icon: Icons.home_outlined,
                title: 'Home',
                onTap: () => _go(context, AppRoutes.home),
              ),
              _drawerTile(
                context,
                selected: currentRoute == AppRoutes.home,
                icon: Icons.menu_book_outlined,
                title: 'Study Material',
                onTap: () => _goWithArgs(
                  context,
                  AppRoutes.home,
                  const {'intent': 'scrollToMaterials'},
                ),
              ),
              _drawerTile(
                context,
                selected: currentRoute == AppRoutes.about,
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => _go(context, AppRoutes.about),
              ),
              _drawerTile(
                context,
                selected: currentRoute == AppRoutes.contact,
                icon: Icons.call_outlined,
                title: 'Contact',
                onTap: () => _go(context, AppRoutes.contact),
              ),
              _drawerTile(
                context,
                selected: currentRoute == AppRoutes.home,
                icon: Icons.rocket_launch_outlined,
                title: 'Get Started',
                onTap: () => _goWithArgs(
                  context,
                  AppRoutes.home,
                  const {'intent': 'openAdmissionDialog'},
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  'ADMIN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                ),
              ),
              _drawerTile(
                context,
                selected: currentRoute == AppRoutes.adminDashboard,
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Dashboard',
                onTap: () => _go(context, AppRoutes.adminDashboard),
              ),
            ],
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: _NotchedNavBar(
        currentIndex: currentIndex,
        currentRoute: currentRoute,
        onGo: (route) => _goBottom(context, currentRoute, route),
      ),
    );
  }

  void _goBottom(BuildContext context, String? currentRoute, String route) {
    if (currentRoute == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _goWithArgs(BuildContext context, String route, Object? arguments) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacementNamed(route, arguments: arguments);
  }

  Widget _drawerTile(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final fg = selected ? Colors.white : Colors.white.withValues(alpha: 0.90);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: AppTheme.brandPrimaryDark.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: fg),
        title: Text(
          title,
          style: TextStyle(
            color: fg,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.55)),
        onTap: onTap,
      ),
    );
  }

  int _bottomIndexForRoute(String? route) {
    switch (route) {
      case AppRoutes.about:
        return 1;
      case AppRoutes.contact:
        return 2;
      case AppRoutes.studentDashboard:
        return 3;
      case AppRoutes.home:
      default:
        return 0;
    }
  }
}

class _NotchedNavBar extends StatelessWidget {
  const _NotchedNavBar({
    required this.currentIndex,
    required this.currentRoute,
    required this.onGo,
  });

  final int currentIndex;
  final String? currentRoute;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: const _BottomNavClipper(),
                child: DecoratedBox(
                  decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _NavItem(
                          selected: currentIndex == 0,
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home,
                          label: 'Home',
                          onTap: () => onGo(AppRoutes.home),
                        ),
                        _NavItem(
                          selected: currentIndex == 1,
                          icon: Icons.info_outline,
                          selectedIcon: Icons.info,
                          label: 'About',
                          onTap: () => onGo(AppRoutes.about),
                        ),
                        const SizedBox(width: 68),
                        _NavItem(
                          selected: currentIndex == 2,
                          icon: Icons.call_outlined,
                          selectedIcon: Icons.call,
                          label: 'Contact',
                          onTap: () => onGo(AppRoutes.contact),
                        ),
                        _NavItem(
                          selected: currentIndex == 3,
                          icon: Icons.school_outlined,
                          selectedIcon: Icons.school,
                          label: 'Student',
                          onTap: () => onGo(AppRoutes.studentDashboard),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.canvas,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              child: GestureDetector(
                onTap: () {
                  if (currentRoute == AppRoutes.home) return;
                  onGo(AppRoutes.home);
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.brandGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withValues(alpha: 0.20), width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.92),
                        border: Border.all(color: AppTheme.canvas.withValues(alpha: 0.55), width: 1.2),
                      ),
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Image.asset(
                            'assets/appicon.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Colors.white.withValues(alpha: 0.80);
    return InkResponse(
      onTap: onTap,
      radius: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: fg),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavClipper extends CustomClipper<Path> {
  const _BottomNavClipper();

  @override
  Path getClip(Size size) {
    const double corner = 22;
    const double notchRadius = 38;
    const double notchCenterGap = 32;
    final double center = size.width / 2;

    final path = Path();
    path.moveTo(0, corner);
    path.quadraticBezierTo(0, 0, corner, 0);

    // Left top edge to notch.
    path.lineTo(center - notchCenterGap - notchRadius, 0);
    path.quadraticBezierTo(center - notchCenterGap - notchRadius + 12, 0, center - notchCenterGap - notchRadius + 18, 14);
    path.arcToPoint(
      Offset(center + notchCenterGap + notchRadius - 18, 14),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(center + notchCenterGap + notchRadius - 12, 0, center + notchCenterGap + notchRadius, 0);

    // Right top edge.
    path.lineTo(size.width - corner, 0);
    path.quadraticBezierTo(size.width, 0, size.width, corner);

    // Bottom rectangle.
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
