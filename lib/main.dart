import 'package:flutter/material.dart';
import 'screens/explore_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const DuvaMobileApp());
}

class DuvaMobileApp extends StatelessWidget {
  const DuvaMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duva Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainLayout(),
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

  // These represent the three tabs from your Expo app
  static const List<Widget> _pages = <Widget>[
    ExploreScreen(),
    MatchesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.explore), // 🧭
            label: 'Pool',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble), // 💬
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), // 👤
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        // Matching tabBarActiveTintColor: '#000' from Expo
        selectedItemColor: Colors.black, 
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}