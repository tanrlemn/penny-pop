import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:penny_pop_app/widgets/pixel_nav_icon.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: PixelNavIcon(
              'assets/icons/nav/overview.svg',
              semanticLabel: 'Overview',
            ),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: PixelNavIcon(
              'assets/icons/nav/pods.svg',
              semanticLabel: 'Pods',
            ),
            label: 'Pods',
          ),
          BottomNavigationBarItem(
            icon: PixelNavIcon(
              'assets/icons/nav/guide.svg',
              semanticLabel: 'Guide',
            ),
            label: 'Guide',
          ),
          BottomNavigationBarItem(
            icon: PixelNavIcon(
              'assets/icons/nav/transactions.svg',
              semanticLabel: 'Transactions',
            ),
            label: 'Transactions',
          ),
        ],
      ),
    );
  }
}
