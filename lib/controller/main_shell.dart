// main_container.dart
import 'package:flutter/material.dart';
import 'package:aqi/view/home.dart';
import 'package:aqi/view/navbar.dart';
import 'package:aqi/view/alert.dart';
import 'package:aqi/view/shopping.dart';
import 'package:aqi/view/health.dart';
import '../theme/app_colors.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;

  // ALL SCREENS (each already has Scaffold inside)
  final List<Widget> _pages = [
    HomeScreen(),
    const ShoppingScreen(),
    const AqiDashboardScreen(),
    const AlertsScreen()
  ];

  final List<NavItem> _navItems = const [
    NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_filled,
      bubbleColor: AppColors.primary,
    ),
    NavItem(
      label: 'Shopping',
      icon: Icons.map_outlined,
      activeIcon: Icons.shopping_cart_outlined,
      bubbleColor: Color(0xFF00BCD4),
    ),
    NavItem(
      label: 'Health',
      icon: Icons.favorite_outline,
      activeIcon: Icons.favorite,
      bubbleColor: Color(0xFF4CAF50),
    ),
    NavItem(
      label: 'Alerts',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_active,
      bubbleColor: Color(0xFFFF9800),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      // ✅ IMPORTANT: IndexedStack keeps UI alive & working
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      bottomNavigationBar: WavyFloatingNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: _navItems,
        backgroundColor: Colors.white,
        iconColor: AppColors.textSecondary,
        activeIconColor: AppColors.primary,
        showLabels: true,
        enableWaveAnimation: true,
        selectedColor: AppColors.textSecondary,
        unselectedColor: AppColors.primary,
      ),
    );
  }
}


