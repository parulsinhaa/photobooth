// lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    _Tab(path: '/camera', icon: Icons.camera_alt_outlined, activeIcon: Icons.camera_alt, label: 'Camera'),
    _Tab(path: '/photobooth', icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library, label: 'Booth'),
    _Tab(path: '/editor', icon: Icons.edit_outlined, activeIcon: Icons.edit, label: 'Edit'),
    _Tab(path: '/discover', icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Discover'),
    _Tab(path: '/orders', icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag, label: 'Orders'),
    _Tab(path: '/profile', icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t.path));
    final activeIndex = currentIndex < 0 ? 0 : currentIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgDark2,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _tabs.asMap().entries.map((entry) {
                final i = entry.key;
                final tab = entry.value;
                final isActive = i == activeIndex;

                return GestureDetector(
                  onTap: () {
                    if (!isActive) {
                      HapticFeedback.selectionClick();
                      context.go(tab.path);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: isActive ? 16 : 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: isActive ? AppColors.primaryGradient : null,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? tab.activeIcon : tab.icon,
                          color: isActive ? Colors.white : AppColors.textMuted,
                          size: 22,
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          Text(
                            tab.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _Tab({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
