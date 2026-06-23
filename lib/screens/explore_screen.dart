import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_profile.dart'; 
import 'notifications_screen.dart';
import 'preferences_screen.dart'; // FIX: Imported the new PreferencesScreen!
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme.dart'; 

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final PageController _pageController = PageController();
  List<MatchProfile> _potentialMatches = [];
  bool _isLoading = true;
  final dio = Dio();
  final String apiUrl = 'https://backend.duvamobile.workers.dev';

  // Advanced Preference States
  List<Map<String, dynamic>> _masterInterests = [];
  List<Map<String, dynamic>> _masterGenders = [];

  @override
  void initState() {
    super.initState();
    _initLocationAndPool();
  }

  Future<Options> _getSecureOptions() async {
    final session = Supabase.instance.client.auth.currentSession;
    return Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'});
  }

  Future<void> _initLocationAndPool() async {
    await _updateUserLocation();
    await _fetchPool();
  }

  Future<void> _updateUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String city = placemarks.isNotEmpty ? "${placemarks.first.locality}, ${placemarks.first.country}" : "Unknown Location";

      final options = await _getSecureOptions();
      await dio.post('$apiUrl/location', data: {'lat': position.latitude, 'lng': position.longitude, 'city': city}, options: options);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<void> _fetchPool() async {
    try {
      final options = await _getSecureOptions();
      final response = await dio.get('$apiUrl/pool', options: options);
      setState(() {
        _potentialMatches = (response.data as List).map((json) => MatchProfile.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching pool: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMasterTablesForFilters() async {
    if (_masterInterests.isNotEmpty && _masterGenders.isNotEmpty) {
      return;
    }
    
    try {
      final supabase = Supabase.instance.client;
      final interests = await supabase.from('master_interests').select();
      final genders = await supabase.from('master_genders').select();
      setState(() {
        _masterInterests = List<Map<String, dynamic>>.from(interests);
        _masterGenders = List<Map<String, dynamic>>.from(genders);
      });
    } catch (e) {
      debugPrint("Error loading filters: $e");
    }
  }

  Future<void> _handleSwipeAction(bool isLike, String profileId) async {
    try {
      final options = await _getSecureOptions();
      final response = await dio.post('$apiUrl/swipe', data: {'swiped_id': profileId, 'action': isLike ? 'like' : 'pass'}, options: options);

      if (response.data['isMatch'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [Icon(Icons.auto_awesome, color: Colors.white), SizedBox(width: 8), Text('MATCH SECURED', style: TextStyle(fontWeight: FontWeight.w900))]), 
            backgroundColor: AppTheme.primaryRose, behavior: SnackBarBehavior.floating
          )
        );
      }

      if (_pageController.page != null && _pageController.page!.toInt() < _potentialMatches.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else {
        setState(() {
          _potentialMatches.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_potentialMatches.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
            child: Image.asset('assets/logo_nobg.png', height: 32, color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune), 
              onPressed: () async {
                // SLEEK SLIDE-UP ANIMATION FIX
                final result = await Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const PreferencesScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0); // Slide up from bottom
                      const end = Offset.zero; // FIX: Offset.zero instead of Offset.0
                      const curve = Curves.easeOutQuart;
                      // FIX: Tween<Offset> instead of Tween
                      var tween = Tween<Offset>(begin: begin, end: end).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);
                      return SlideTransition(position: offsetAnimation, child: child);
                    },
                  ),
                );
                // Refresh pool if filters applied
                if (result == true) {
                  setState(() {
                    _isLoading = true;
                  });
                  _fetchPool();
                }
              }
            )
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.radar, size: 80, color: AppTheme.textSecondary),
              const SizedBox(height: 24),
              const Text('Scanning the Void', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('No profiles match your advanced filters.', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true, // Make app bar float over the image!
      appBar: AppBar(
        title: Image.asset('assets/logo_nobg.png', height: 32, color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]), 
            onPressed: () async {
              // SLEEK SLIDE-UP ANIMATION FIX
              final result = await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const PreferencesScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0); // Slide up from bottom
                    const end = Offset.zero; // FIX: Offset.zero
                    const curve = Curves.easeOutQuart;
                    // FIX: Tween<Offset>
                    var tween = Tween<Offset>(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(position: offsetAnimation, child: child);
                  },
                ),
              );
              // Refresh pool if filters applied
              if (result == true) {
                setState(() {
                  _isLoading = true;
                });
                _fetchPool();
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController, 
        physics: const BouncingScrollPhysics(), // Modern bouncy physics
        itemCount: _potentialMatches.length,
        itemBuilder: (context, index) {
          // PARALLAX ANIMATION LOGIC
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0); // Scale down to 70%
              }
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.5, 1.0), // Fade slightly
                  child: child,
                ),
              );
            },
            child: _buildCinematicProfileCard(_potentialMatches[index]),
          );
        }
      ),
    );
  }

  // --- THE CINEMATIC "2026" EDGE-TO-EDGE CARD ---
  Widget _buildCinematicProfileCard(MatchProfile profile) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. The massive background image
        if (profile.images.isNotEmpty)
          Image.network(profile.images.first, fit: BoxFit.cover),
        
        // 2. The gradient shadow to make text legible
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black, Colors.black87, Colors.transparent, Colors.transparent],
              stops: [0.0, 0.4, 0.6, 1.0]
            ),
          ),
        ),

        // 3. The Content pushed to the bottom
        Positioned(
          bottom: 120, // Leave room for buttons
          left: 24, right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Glass Date Bid
              if (profile.currentDateBid != null && profile.currentDateBid!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppTheme.primaryRose.withValues(alpha: 0.3), border: Border.all(color: AppTheme.primaryRose.withValues(alpha: 0.5))),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_bar, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Flexible(child: Text(profile.currentDateBid!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Name and Age
              Text('${profile.firstName}, ${profile.age}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1, height: 1.1)),
              const SizedBox(height: 8),

              // Location Info
              Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.electricCyan, size: 18),
                  const SizedBox(width: 6),
                  Text('${profile.location} • ${profile.distance} km', style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),

              // Glass Interest Tags
              if (profile.interests.isNotEmpty)
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: profile.interests.take(4).map((interest) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), border: Border.all(color: Colors.white24)),
                          child: Text(interest, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),

        // 4. Floating Action Buttons (Pass / Like) at absolute bottom
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGlassButton(Icons.close, Colors.white, () => _handleSwipeAction(false, profile.id)),
              const SizedBox(width: 32),
              _buildGlassButton(Icons.favorite, AppTheme.primaryRose, () => _handleSwipeAction(true, profile.id)),
              const SizedBox(width: 32),
              _buildGlassButton(Icons.info_outline, AppTheme.electricCyan, () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full profile modal coming soon!')));
              }, size: 50), 
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton(IconData icon, Color color, VoidCallback onTap, {double size = 64}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Icon(icon, color: color, size: size * 0.5),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}