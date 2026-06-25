import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart'; // THE NEW SWIPE ENGINE
import '../models/match_profile.dart'; 
import 'preferences_screen.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme.dart'; 
import '../widgets/premium_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // Controller to programmatically swipe cards (when buttons are tapped)
  final CardSwiperController _swiperController = CardSwiperController();
  
  List<MatchProfile> _potentialMatches = [];
  bool _isLoading = true;
  bool _isPremium = false;
  final dio = Dio();
  final String apiUrl = dotenv.env['BACKEND_URL'] ?? 'https://backend.duvamobile.workers.dev';
  

  Future<void> _triggerRewind() async {
    if (!_isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade to Duva Black to rewind alignments!')));
      return;
    }
    
    // Call the swiper package's native undo mechanism
    _swiperController.undo();
    
    // Tell the backend to delete the mistake
    try {
      final options = await _getSecureOptions();
      await dio.post('$apiUrl/rewind', options: options);
    } catch (e) {
      debugPrint("Rewind Backend Sync Failed");
    }
  }

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
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId != null) {
      final profile = await Supabase.instance.client.from('profiles').select('is_premium').eq('id', myId).single();
      if (mounted) setState(() => _isPremium = profile['is_premium'] ?? false);
    }
    await _updateUserLocation();
    await _fetchPool();
  }

  Future<void> _updateUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      String city = "Unknown Location";
      if (placemarks.isNotEmpty) {
        final mark = placemarks.first;
        city = [mark.locality, mark.country].where((e) => e != null && e.isNotEmpty).join(', ');
        if (city.isEmpty) city = "Unknown Location";
      }

      final options = await _getSecureOptions();
      await dio.post('$apiUrl/location', data: {'lat': position.latitude, 'lng': position.longitude, 'city': city}, options: options);
    } catch (e) {
      debugPrint("Location error ignored safely: $e");
    }
  }

  Future<void> _fetchPool() async {
    try {
      final options = await _getSecureOptions();
      final response = await dio.get('$apiUrl/pool', options: options);
      
      if (mounted) {
        setState(() {
          _potentialMatches = (response.data as List).map((json) => MatchProfile.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FIRES WHEN THE CARD FINISHES SWIPING
  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    final profileId = _potentialMatches[previousIndex].id;
    
    if (direction == CardSwiperDirection.right) {
      _executeSwipeBackend(true, profileId);
    } else if (direction == CardSwiperDirection.left) {
      _executeSwipeBackend(false, profileId);
    }
    return true; // Allow the swipe to complete
  }

  // FIRES WHEN THE STACK IS EMPTY
  void _onEnd() {
    setState(() {
      _potentialMatches.clear();
    });
  }

  Future<void> _executeSwipeBackend(bool isLike, String profileId) async {
    HapticFeedback.heavyImpact();
    try {
      final options = await _getSecureOptions();
      final response = await dio.post('$apiUrl/swipe', data: {'swiped_id': profileId, 'action': isLike ? 'like' : 'pass'}, options: options);

      if (response.data['isMatch'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [Icon(Icons.auto_awesome, color: Colors.white), SizedBox(width: 8), Text('ALIGNMENT SECURED', style: TextStyle(fontWeight: FontWeight.w900))]), 
            backgroundColor: AppTheme.primaryRose, behavior: SnackBarBehavior.floating
          )
        );
      }
    } catch (e) {
      debugPrint("Swipe Network Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- THE NEW 2026 SKELETON LOADER ---
    if (_isLoading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: Padding(
          padding: const EdgeInsets.only(bottom: 24.0), // Space for nav bar
          child: PremiumShimmer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The massive profile image placeholder
                ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 0),
                
                // The text placeholders at the bottom
                Positioned(
                  bottom: 120, left: 24, right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 150, height: 40, borderRadius: 12), // Name/Age
                      const SizedBox(height: 12),
                      ShimmerBox(width: 200, height: 20, borderRadius: 8), // Location
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ShimmerBox(width: 80, height: 30, borderRadius: 20), // Tags
                          const SizedBox(width: 8),
                          ShimmerBox(width: 100, height: 30, borderRadius: 20),
                        ],
                      )
                    ],
                  ),
                ),
                
                // The action button placeholders
                Positioned(
                  bottom: 40, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShimmerBox(width: 64, height: 64, borderRadius: 32),
                      const SizedBox(width: 32),
                      ShimmerBox(width: 64, height: 64, borderRadius: 32),
                      const SizedBox(width: 32),
                      ShimmerBox(width: 50, height: 50, borderRadius: 25),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_potentialMatches.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(),
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
      extendBodyBehindAppBar: true, 
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // 1. THE PHYSICS SWIPER
          CardSwiper(
            controller: _swiperController,
            cardsCount: _potentialMatches.length,
            onSwipe: _onSwipe,
            onEnd: _onEnd,
            allowedSwipeDirection: const AllowedSwipeDirection.symmetric(horizontal: true),
            numberOfCardsDisplayed: 2, // Shows the next card stacked slightly behind
            backCardOffset: const Offset(0, 0), // Keeps it perfectly aligned
            padding: EdgeInsets.zero, // Edge-to-edge
            cardBuilder: (context, index, horizontalThresholdPercentage, verticalThresholdPercentage) {
              return CinematicProfileCard(
                profile: _potentialMatches[index],
                swipeProgress: horizontalThresholdPercentage, // Powers the ALIGN/PASS stamps
              );
            },
          ),

          // 2. STATIC ACTION DOCK (Hovering over the cards)
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGlassButton(Icons.replay, Colors.amber, _triggerRewind, size: 50),
                const SizedBox(width: 24),
                _buildGlassButton(Icons.close, Colors.white, () => _swiperController.swipe(CardSwiperDirection.left)),
                const SizedBox(width: 32),
                _buildGlassButton(Icons.favorite, AppTheme.primaryRose, () => _swiperController.swipe(CardSwiperDirection.right)),
                const SizedBox(width: 32),
                _buildGlassButton(Icons.info_outline, AppTheme.electricCyan, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full profile modal coming soon!')));
                }, size: 50), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Image.asset('assets/logo_nobg.png', height: 32, color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]), 
          onPressed: () async {
            final result = await Navigator.push(context, PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const PreferencesScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                var tween = Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutQuart));
                return SlideTransition(position: animation.drive(tween), child: child);
              },
            ));
            if (result == true && mounted) {
              setState(() => _isLoading = true);
              _fetchPool();
            }
          },
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
    _swiperController.dispose();
    super.dispose();
  }
}

// =========================================================================
// THE INSTAGRAM STORY + DYNAMIC STAMP CARD
// =========================================================================

class CinematicProfileCard extends StatefulWidget {
  final MatchProfile profile;
  final int swipeProgress; // Automatically passed by CardSwiper (-10000 to 10000)

  const CinematicProfileCard({
    super.key,
    required this.profile,
    required this.swipeProgress,
  });

  @override
  State<CinematicProfileCard> createState() => _CinematicProfileCardState();
}

class _CinematicProfileCardState extends State<CinematicProfileCard> {
  int _currentImageIndex = 0;

  void _handleTap(TapUpDetails details) {
    if (widget.profile.images.isEmpty) return;

    HapticFeedback.lightImpact();

    final double screenWidth = MediaQuery.of(context).size.width;
    final double tapPosition = details.globalPosition.dx;

    setState(() {
      if (tapPosition < screenWidth * 0.3) {
        if (_currentImageIndex > 0) _currentImageIndex--; // Prev Image
      } else {
        if (_currentImageIndex < widget.profile.images.length - 1) _currentImageIndex++; // Next Image
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    
    // Calculate Opacity for the Stamps based on Swipe Progress
    // flutter_card_swiper passes int values where 10000 = 100% swiped
    double progress = widget.swipeProgress / 10000; 
    double likeOpacity = (progress * 2).clamp(0.0, 1.0); // Multiplied by 2 so it fades in faster
    double passOpacity = (-progress * 2).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. The Image (Wrapped in GestureDetector for Insta-taps)
        GestureDetector(
          onTapUp: _handleTap,
          child: profile.images.isNotEmpty
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Image.network(
                    profile.images[_currentImageIndex], 
                    key: ValueKey<String>(profile.images[_currentImageIndex]),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.surfaceGlass, child: const Center(child: Icon(Icons.person, size: 100, color: Colors.white24))),
                  ),
                )
              : Container(color: AppTheme.surfaceGlass, child: const Center(child: Icon(Icons.person, size: 100, color: Colors.white24))),
        ),
        
        // 2. The Gradient shadow to make text legible
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

        // 3. The Insta-Story Progress Bars (At the very top)
        if (profile.images.length > 1)
          Positioned(
            top: 110, // Just below the AppBar
            left: 16, right: 16,
            child: Row(
              children: List.generate(profile.images.length, (index) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.0),
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: index <= _currentImageIndex ? Colors.white : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.0),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2)],
                    ),
                  ),
                );
              }),
            ),
          ),

        // 4. THE DYNAMIC STAMPS (Fades in based on thumb drag)
        if (likeOpacity > 0.0)
          Positioned(
            top: 160, left: 40,
            child: Transform.rotate(
              angle: -0.2, // Slightly tilted
              child: Opacity(
                opacity: likeOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.electricCyan, width: 4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('ALIGN', style: TextStyle(color: AppTheme.electricCyan, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
                ),
              ),
            ),
          ),

        if (passOpacity > 0.0)
          Positioned(
            top: 160, right: 40,
            child: Transform.rotate(
              angle: 0.2,
              child: Opacity(
                opacity: passOpacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryRose, width: 4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('PASS', style: TextStyle(color: AppTheme.primaryRose, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
                ),
              ),
            ),
          ),

        // 5. The Content pushed to the bottom
        Positioned(
          bottom: 120, 
          left: 24, right: 24,
          child: IgnorePointer( // Let taps pass through to the image
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Text('${profile.firstName}, ${profile.age}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1, height: 1.1)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.electricCyan, size: 18),
                    const SizedBox(width: 6),
                    Text('${profile.location} • ${profile.distance} km', style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
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
        ),
      ],
    );
  }
}