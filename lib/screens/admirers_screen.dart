import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/premium_shimmer.dart';
import '../widgets/profile_modal.dart';

class AdmirersScreen extends StatefulWidget {
  const AdmirersScreen({super.key});

  @override
  State<AdmirersScreen> createState() => _AdmirersScreenState();
}

class _AdmirersScreenState extends State<AdmirersScreen> {
  bool _isLoading = true;
  bool _isPremium = false; // THE PRO LOCK
  List<dynamic> _admirers = [];
  final String apiUrl = 'https://backend.duvamobile.workers.dev';
  final dio = Dio();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final options = Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'});
      
      // Fetch User's Premium Status
      final myId = session?.user.id;
      final profile = await Supabase.instance.client.from('profiles').select('is_premium').eq('id', myId!).single();
      _isPremium = profile['is_premium'] ?? false;

      // Fetch Admirers
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.voidBackground,
        appBar: _buildAppBar(),
        body: PremiumShimmer(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75
            ),
            itemCount: 6, 
            itemBuilder: (context, index) => const ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 24),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: _buildAppBar(),
      body: _admirers.isEmpty ? _buildEmptyState() : _buildGrid(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
            child: Image.asset('assets/logo_nobg.png', height: 28, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text('ADMIRERS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5, color: Colors.white)),
        ],
      ),
      backgroundColor: AppTheme.surfaceGlass,
      elevation: 0,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          const Text('No Admirers Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          const Text('Keep swiping. Your alignments are out there.', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Column(
      children: [
        if (!_isPremium)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            width: double.infinity,
            decoration: BoxDecoration(color: AppTheme.primaryRose.withValues(alpha: 0.1)),
            child: Column(
              children: [
                const Text('Upgrade to Duva Black', style: TextStyle(color: AppTheme.primaryRose, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('See who already liked you and match instantly.', style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75
            ),
            itemCount: _admirers.length,
            itemBuilder: (context, index) {
              final admirer = _admirers[index];
              final String imageUrl = (admirer['images'] != null && admirer['images'].isNotEmpty) ? admirer['images'][0] : 'https://via.placeholder.com/400';

              return GestureDetector(
                onTap: () {
                  if (!_isPremium) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unlock Duva Black to reveal their photos & match!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppTheme.primaryRose,
                      )
                    );
                    // Optional: Route to your paywall screen here
                  } else {
                    // ✅ FEATURE 1 TRIGGERED: Open full profile modal for Pro users!
                    ProfileModal.show(
                      context: context,
                      profile: admirer,
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(imageUrl, fit: BoxFit.cover),
                      
                      // THE PAYWALL BLUR
                      if (!_isPremium)
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(color: AppTheme.voidBackground.withValues(alpha: 0.35)),
                        ),
                      
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppTheme.voidBackground.withValues(alpha: 0.9), Colors.transparent]),
                        ),
                      ),
                      
                      // ✅ FEATURE 3: DYNAMIC TEASE PILL FOR NON-PRO USERS
                      if (!_isPremium)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primaryRose.withValues(alpha: 0.6), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock, color: AppTheme.primaryRose, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    (admirer['interests'] != null && (admirer['interests'] as List).isNotEmpty)
                                        ? 'Likes ${admirer['interests'][0]}'
                                        : '${admirer['distance'] ?? 4} km away',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // IF PREMIUM, SHOW THEIR NAME & AGE
                      if (_isPremium)
                        Positioned(
                          bottom: 12, left: 12, right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${admirer['first_name'] ?? 'Secret'}, ${admirer['age'] ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                              Text(admirer['location'] ?? 'Nearby', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        )
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