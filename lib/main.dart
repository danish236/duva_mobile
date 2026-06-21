import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/explore_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme.dart';
import 'theme_notifier.dart'; // Import this to access themeNotifier

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load the .env file
  await dotenv.load(fileName: ".env");

  // 2. Initialize Supabase using the loaded variables
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
    // This ValueListenableBuilder listens to your theme toggle
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Duva Mobile',
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
    MatchesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: colorScheme.surface,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Pool'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.hotPink, 
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}