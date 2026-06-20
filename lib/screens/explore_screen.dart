import 'package:flutter/material.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pool')),
      body: const Center(
        child: Text('🧭 Explore Pool Content Here', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}