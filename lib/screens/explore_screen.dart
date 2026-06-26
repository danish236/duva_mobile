import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart'; 
import '../models/match_profile.dart'; 
import 'preferences_screen.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../theme.dart'; 
import '../widgets/premium_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/profile_modal.dart';
import '../constants.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  
  final List<MatchProfile> _potentialMatches = [];
  bool _isLoading = true;
  bool _isPremium = false;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final dio = Dio();
  final String apiUrl = dotenv.env['BACKEND_URL'] ?? 'https://backend.duvamobile.workers.dev';
  
  Future<void> _triggerRewind() async {
    if (!_isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upgrade to Duva Black to rewind!')));
      return;
    }
    if (_potentialMatches.isEmpty) return;

    try {
      final options = await _getSecureOptions();
      final response = await dio.post('$apiUrl/rewind', options: options);
      
      if (response.statusCode == 200 && mounted) {
        _swiperController.undo();
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data['error'] ?? 'Cannot rewind this alignment.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.primaryRose));
      }
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
      if (mounted) {
        setState(() {
          _isPremium = profile['is_premium'] ?? false;
        });
      }
    }

    _hasMore = true;
    _currentPage = 0;
    _potentialMatches.clear();

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
    if (!_hasMore || _isFetchingMore) return; 

    setState(() {
      _isFetchingMore = true; 
    });

    try {
      final options = await _getSecureOptions();
      final response = await dio.get('$apiUrl/pool?page=$_currentPage', options: options);
      
      if (!mounted) return; 

      setState(() {
        final newData = (response.data['data'] as List)
            .map((json) => MatchProfile.fromJson(json))
            .toList();
        
        _potentialMatches.addAll(newData);
        _currentPage = response.data['nextPage'] ?? _currentPage;
        _hasMore = response.data['nextPage'] != null;
        _isLoading = false;
      });

      for (int i = 0; i < 3 && i < _potentialMatches.length; i++) {
        if (_potentialMatches[i].images.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(_potentialMatches[i].images.first), context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
        });
      }
    }
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    final profileId = _potentialMatches[previousIndex].id;
    
    if (direction == CardSwiperDirection.right) {
      _executeSwipeBackend('like', profileId);
    } else if (direction == CardSwiperDirection.left) {
      _executeSwipeBackend('pass', profileId);
    } else if (direction == CardSwiperDirection.top) {
      _executeSwipeBackend('superlike', profileId);
    }

    if (currentIndex != null && currentIndex >= _potentialMatches.length - AppConstants.paginationTriggerOffset) {
      _fetchPool();
    }
    
    return true; 
  }

  void _onEnd() {
    setState(() {
      _potentialMatches.clear();
    });
  }

  Future<void> _executeSwipeBackend(String action, String profileId) async {
    HapticFeedback.heavyImpact();
    try {
      final options = await _getSecureOptions();
      final response = await dio.post(
        '$apiUrl/swipe', 
        data: {'swiped_id': profileId, 'action': action}, 
        options: options
      );

      if (response.data['isMatch'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [Icon(Icons.auto_awesome, color: Colors.white), SizedBox(width: 8), Text('ALIGNMENT SECURED', style: TextStyle(fontWeight: FontWeight.w900))]), 
            backgroundColor: AppTheme.primaryRose, behavior: SnackBarBehavior.floating
          )
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 402 && e.response?.data['outOfBalance'] == true) {
        _swiperController.undo(); 
        if (mounted) _showBuySuperlikesSheet();
      } else {
        debugPrint("Swipe Network Error: ${e.message}");
      }
    } catch (e) {
      debugPrint("Swipe Error: $e");
    }
  }

  void _showBuySuperlikesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.voidBackground, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), 
          border: Border.all(color: AppTheme.electricCyan.withValues(alpha: 0.3))
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flare, color: AppTheme.electricCyan, size: 64), 
              const SizedBox(height: 16),
              const Text('OUT OF SUPER ALIGNMENTS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('Stand out from the void. Super alignments are 3x more likely to result in a match.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.electricCyan, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Processing ₹300 payment for 10 Superlikes...')));
                  },
                  child: const Text('GET 10 FOR ₹300', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('MAYBE LATER', style: TextStyle(color: Colors.white54)),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showModerationOptions(MatchProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900], 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.white),
                title: Text('Unmatch & Block ${profile.firstName}', style: const TextStyle(color: Colors.white)),
                subtitle: const Text('They won\'t know you blocked them.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _executeModerationAction('block', profile.id, null);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: AppTheme.primaryRose),
                title: Text('Report ${profile.firstName}', style: const TextStyle(color: AppTheme.primaryRose)),
                subtitle: const Text('Report inappropriate behavior or fake profiles.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _fetchAndShowReportReasons(profile);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Future<void> _fetchAndShowReportReasons(MatchProfile profile) async {
    try {
      final options = await _getSecureOptions();
      final response = await dio.get('$apiUrl/reasons?type=report', options: options);
      final List reasons = response.data;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Why are you reporting this profile?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ...reasons.map((reason) => ListTile(
                    title: Text(reason['reason'], style: const TextStyle(color: Colors.white70)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                    onTap: () {
                      Navigator.pop(context);
                      _executeModerationAction('report', profile.id, reason['id']);
                    },
                  )),
                ],
              ),
            ),
          );
        }
      );
    } catch (e) {
      debugPrint('Failed to load reasons: $e');
    }
  }

  Future<void> _executeModerationAction(String action, String targetId, int? reasonId) async {
    setState(() {
      _potentialMatches.removeWhere((p) => p.id == targetId);
    });
    
    try {
      final options = await _getSecureOptions();
      final endpoint = action == 'report' ? '/report' : '/block';
      
      await dio.post(
        '$apiUrl$endpoint', 
        data: action == 'report' ? {'reported_id': targetId, 'reason_id': reasonId} : {'blocked_id': targetId, 'reason_id': 1}, 
        options: options
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile removed securely.'),
          backgroundColor: Colors.black87,
        ));
      }
    } catch (e) {
      debugPrint('Moderation API failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(),
        body: Padding(
          padding: const EdgeInsets.only(bottom: 24.0), 
          child: PremiumShimmer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ShimmerBox(width: double.infinity, height: double.infinity, borderRadius: 0),
                Positioned(
                  bottom: 120, left: 24, right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(width: 150, height: 40, borderRadius: 12), 
                      const SizedBox(height: 12),
                      ShimmerBox(width: 200, height: 20, borderRadius: 8), 
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ShimmerBox(width: 80, height: 30, borderRadius: 20), 
                          const SizedBox(width: 8),
                          ShimmerBox(width: 100, height: 30, borderRadius: 20),
                        ],
                      )
                    ],
                  ),
                ),
                Positioned(
                  bottom: 40, left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShimmerBox(width: 50, height: 50, borderRadius: 25),
                      const SizedBox(width: 16),
                      ShimmerBox(width: 64, height: 64, borderRadius: 32),
                      const SizedBox(width: 16),
                      ShimmerBox(width: 50, height: 50, borderRadius: 25),
                      const SizedBox(width: 16),
                      ShimmerBox(width: 64, height: 64, borderRadius: 32),
                      const SizedBox(width: 16),
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
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.electricCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasMore = true;
                    _currentPage = 0;
                  });
                  _fetchPool();
                },
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('FORCE RESCAN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              ),
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
          CardSwiper(
            controller: _swiperController,
            cardsCount: _potentialMatches.length,
            onSwipe: _onSwipe,
            onEnd: _onEnd,
            allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true, up: true),
            numberOfCardsDisplayed: 2, 
            backCardOffset: const Offset(0, 0), 
            padding: EdgeInsets.zero, 
            cardBuilder: (context, index, horizontalThresholdPercentage, verticalThresholdPercentage) {
              return CinematicProfileCard(
                profile: _potentialMatches[index],
                swipeProgress: horizontalThresholdPercentage, 
                verticalSwipeProgress: verticalThresholdPercentage,
                onMoreTap: () => _showModerationOptions(_potentialMatches[index]),
              );
            },
          ),
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildGlassButton(Icons.replay, Colors.amber, _triggerRewind, size: 50),
                const SizedBox(width: 16),
                _buildGlassButton(Icons.close, Colors.white, () => _swiperController.swipe(CardSwiperDirection.left)),
                const SizedBox(width: 16),
                _buildGlassButton(Icons.flare, AppTheme.electricCyan, () => _swiperController.swipe(CardSwiperDirection.top), size: 50),
                const SizedBox(width: 16),
                _buildGlassButton(Icons.favorite, AppTheme.primaryRose, () => _swiperController.swipe(CardSwiperDirection.right)),
                const SizedBox(width: 16),
                _buildGlassButton(Icons.info_outline, AppTheme.electricCyan, () {
                  if (_potentialMatches.isEmpty) return; 
                  final topProfile = _potentialMatches.first;
                  ProfileModal.show(
                    context: context,
                    profile: topProfile.toJson(), 
                    onLike: () => _swiperController.swipe(CardSwiperDirection.right),
                    onPass: () => _swiperController.swipe(CardSwiperDirection.left),
                  );
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
              setState(() {
                _isLoading = true;
                _hasMore = true;
                _currentPage = 0;
              });
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
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Icon(icon, color: color, size: size * 0.5),
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

class CinematicProfileCard extends StatefulWidget {
  final MatchProfile profile;
  final int swipeProgress; 
  final int verticalSwipeProgress;
  final VoidCallback onMoreTap; 

  const CinematicProfileCard({
    super.key,
    required this.profile,
    required this.swipeProgress,
    required this.verticalSwipeProgress,
    required this.onMoreTap, 
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
        if (_currentImageIndex > 0) _currentImageIndex--; 
      } else {
        if (_currentImageIndex < widget.profile.images.length - 1) _currentImageIndex++; 
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    
    double progress = widget.swipeProgress / 10000; 
    double vProgress = widget.verticalSwipeProgress / 10000;

    double likeOpacity = (progress * 2).clamp(0.0, 1.0); 
    double passOpacity = (-progress * 2).clamp(0.0, 1.0);
    double superOpacity = (-vProgress * 2).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTapUp: _handleTap,
          child: profile.images.isNotEmpty
              ? AnimatedSwitcher(
                  duration: AppConstants.imageTransitionDuration,
                  child: CachedNetworkImage(
                    key: ValueKey<String>(profile.images[_currentImageIndex]),
                    imageUrl: profile.images[_currentImageIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    fadeInDuration: const Duration(milliseconds: 100), 
                    placeholder: (context, url) => Container(color: AppTheme.surfaceGlass, child: const Center(child: CircularProgressIndicator(color: AppTheme.electricCyan))),
                    errorWidget: (context, url, error) => Container(color: AppTheme.surfaceGlass, child: const Center(child: Icon(Icons.broken_image, size: 100, color: Colors.white24))),
                  ),
                )
              : Container(color: AppTheme.surfaceGlass, child: const Center(child: Icon(Icons.person, size: 100, color: Colors.white24))),
        ),
        
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

        Positioned(
          top: 50, right: 16,
          child: IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
            onPressed: widget.onMoreTap,
          ),
        ),

        if (profile.images.length > 1)
          Positioned(
            top: 110, 
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

        if (likeOpacity > 0.0)
          Positioned(
            top: 160, left: 40,
            child: Transform.rotate(
              angle: -0.2, 
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

        if (superOpacity > 0.0)
          Positioned(
            bottom: 250, left: 0, right: 0,
            child: Transform.rotate(
              angle: -0.1,
              child: Opacity(
                opacity: superOpacity,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.electricCyan, width: 4),
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.electricCyan.withValues(alpha: 0.2),
                    ),
                    child: const Text('SUPER', style: TextStyle(color: AppTheme.electricCyan, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
                  ),
                ),
              ),
            ),
          ),

        Positioned(
          bottom: 120, 
          left: 24, right: 24,
          child: IgnorePointer( 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.currentDateBid != null && profile.currentDateBid!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppTheme.primaryRose.withValues(alpha: 0.8), border: Border.all(color: AppTheme.primaryRose)),
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
                const SizedBox(height: 16),
                
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: profile.activeStatusColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: profile.activeStatusColor,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: profile.activeStatusColor, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        profile.activeStatusText,
                        style: TextStyle(color: profile.activeStatusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),

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
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), border: Border.all(color: Colors.white24)),
                          child: Text(interest, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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