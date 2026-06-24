import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/explore_screen.dart';
import 'screens/admirers_screen.dart';
import 'screens/premium_screen.dart'; 
import 'screens/matches_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';

import 'theme.dart';
import 'theme_notifier.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.get('SUPABASE_URL'),
    publishableKey: dotenv.get('SUPABASE_ANON_KEY'),
  );
  runApp(const DuvaMobileApp());
}

class DuvaMobileApp extends StatelessWidget {
  const DuvaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Duva',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode, 
          home: StreamBuilder<AuthState>(
            stream: Supabase.instance.client.auth.onAuthStateChange,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.session != null) {
                return const MainLayout();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  
  static const List<Widget> _pages = <Widget>[
    ExploreScreen(),
    AdmirersScreen(),
    PremiumScreen(), 
    MatchesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Crucial: Allows content to flow UNDER the floating dock
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutQuart,
        switchOutCurve: Curves.easeInQuart,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // Modern Fade & Slight Scale transition
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _pages[_selectedIndex],
      ),
      // THE FLOATING GLASS DOCK
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGlass.withValues(alpha: 0.75),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.style_outlined, Icons.style, 0),
                    _buildNavItem(Icons.favorite_border, Icons.favorite, 1),
                    _buildPremiumNavItem(),
                    _buildNavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 3),
                    _buildNavItem(Icons.person_outline, Icons.person, 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData outlineIcon, IconData filledIcon, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Icon(
          isSelected ? filledIcon : outlineIcon,
          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
          size: isSelected ? 28 : 24, // Icon pops slightly when selected
        ),
      ),
    );
  }

  Widget _buildPremiumNavItem() {
    final isSelected = _selectedIndex == 2;
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isSelected ? const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]) : null,
          color: isSelected ? null : Colors.transparent,
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.4), blurRadius: 15)] : [],
        ),
        child: ShaderMask(
          shaderCallback: (bounds) => isSelected 
              ? const LinearGradient(colors: [Colors.white, Colors.white]).createShader(bounds)
              : const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
          child: Icon(
            isSelected ? Icons.diamond : Icons.diamond_outlined,
            color: Colors.white,
            size: isSelected ? 28 : 26,
          ),
        ),
      ),
    );
  }
}