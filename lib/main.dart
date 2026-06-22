import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/explore_screen.dart';
import 'screens/admirers_screen.dart';
import 'screens/premium_screen.dart'; // NEW
import 'screens/matches_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';

import 'theme.dart';
import 'theme_notifier.dart';

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
    PremiumScreen(), // THE NEW PREMIUM PLACEHOLDER
    MatchesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Smooth cross-fade animation when switching tabs!
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1))
        ),
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(icon: Icon(Icons.style_outlined), activeIcon: Icon(Icons.style), label: 'Discover'),
            const BottomNavigationBarItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: 'Admirers'),
            
            // The Premium Center Tab (Glowing icon effect)
            BottomNavigationBarItem(
              icon: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
                child: const Icon(Icons.diamond_outlined, color: Colors.white),
              ),
              activeIcon: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
                child: const Icon(Icons.diamond, color: Colors.white),
              ),
              label: 'Premium',
            ),

            const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Matches'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}