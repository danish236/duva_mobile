import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class AdmirersScreen extends StatefulWidget {
  const AdmirersScreen({super.key});

  @override
  State<AdmirersScreen> createState() => _AdmirersScreenState();
}

class _AdmirersScreenState extends State<AdmirersScreen> {
  bool _isLoading = true;
  List<dynamic> _admirers = [];
  final String apiUrl = 'https://backend.duvamobile.workers.dev';
  final dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchAdmirers();
  }

  Future<void> _fetchAdmirers() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final options = Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'});
      // Assuming you will create this endpoint, falling back to /matches if it doesn't exist for now so UI doesn't crash
      final response = await dio.get('$apiUrl/matches', options: options); 
      
      if (mounted) {
        setState(() {
          _admirers = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secret Admirers'),
        actions: [
          IconButton(icon: const Icon(Icons.auto_awesome), onPressed: () {}), // Premium upgrade trigger later
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _admirers.isEmpty 
          ? _buildEmptyState() 
          : _buildGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          const Text('No Admirers Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Keep swiping. Your alignments are out there.', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          width: double.infinity,
          decoration: BoxDecoration(color: AppTheme.primaryRose.withValues(alpha: 0.1)),
          child: Column(
            children: [
              const Text('Upgrade to Premium', style: TextStyle(color: AppTheme.primaryRose, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text('See who already liked you and match instantly.', style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.8), fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              crossAxisSpacing: 16, 
              mainAxisSpacing: 16,
              childAspectRatio: 0.75
            ),
            itemCount: _admirers.length,
            itemBuilder: (context, index) {
              final admirer = _admirers[index];
              final String imageUrl = (admirer['images'] != null && admirer['images'].isNotEmpty) 
                  ? admirer['images'][0] 
                  : 'https://via.placeholder.com/400';

              return GestureDetector(
                onTap: () {
                  // Trigger premium paywall modal here in the future
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlock Premium to reveal!')));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(imageUrl, fit: BoxFit.cover),
                      
                      // THE HEAVY BLUR EFFECT
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(color: AppTheme.voidBackground.withValues(alpha: 0.2)),
                      ),
                      
                      // GRADIENT OVERLAY
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppTheme.voidBackground, AppTheme.voidBackground.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                      
                      // LOCK ICON
                      const Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.white24,
                          radius: 30,
                          child: Icon(Icons.lock_outline, color: Colors.white, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}