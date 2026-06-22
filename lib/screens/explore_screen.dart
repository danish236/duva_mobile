import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_profile.dart'; 
import 'notifications_screen.dart';
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
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

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
      setState(() => _isLoading = false);
    }
  }

  void _showPreferencesSheet() {
    RangeValues currentAgeRange = const RangeValues(18, 40);
    double currentDistance = 50.0; 
    String selectedExpectation = 'Any';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom, left: 24, right: 24, top: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discovery Preferences', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Age Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                      Text('${currentAgeRange.start.round()} - ${currentAgeRange.end.round()}', style: const TextStyle(color: AppTheme.skySurge, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  RangeSlider(
                    values: currentAgeRange, min: 18, max: 65, divisions: 47, activeColor: AppTheme.skySurge,
                    onChanged: (RangeValues values) { setSheetState(() => currentAgeRange = values); },
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Maximum Distance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                      Text('${currentDistance.round()} km', style: const TextStyle(color: AppTheme.skySurge, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Slider(
                    value: currentDistance, min: 5, max: 160, divisions: 31, activeColor: AppTheme.skySurge,
                    onChanged: (value) => setSheetState(() => currentDistance = value),
                  ),
                  const SizedBox(height: 24),

                  Text('Looking For', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.skySurge.withValues(alpha: 0.3), width: 2)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true, value: selectedExpectation,
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.skySurge),
                        items: ['Any', 'Long-term relationship', 'Casual dating', 'New friends'].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)));
                        }).toList(),
                        onChanged: (newValue) { setSheetState(() => selectedExpectation = newValue!); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity, 
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        setSheetState(() => isSaving = true);
                        try {
                          final options = await _getSecureOptions();
                          await dio.post('$apiUrl/preferences', data: {'min_age': currentAgeRange.start.round(), 'max_age': currentAgeRange.end.round(), 'max_distance': currentDistance.round(), 'filter_expectation': selectedExpectation}, options: options);
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext); 
                          setState(() { _isLoading = true; _potentialMatches.clear(); });
                          _fetchPool();
                        } catch (e) { setSheetState(() => isSaving = false); }
                      },
                      child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('APPLY FILTERS'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _showSafetySheet(String profileId, String profileName, String type) async {
    List<dynamic> reasons = [];
    bool isFetchingReasons = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            if (isFetchingReasons) {
              _getSecureOptions().then((options) {
                dio.get('$apiUrl/reasons?type=$type', options: options).then((response) {
                  setSheetState(() { reasons = response.data; isFetchingReasons = false; });
                });
              });
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type == 'block' ? 'Block $profileName' : 'Report $profileName', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: type == 'report' ? AppTheme.hotPink : Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  const Text('This will notify our Trust & Safety team. The user will be hidden from your pool.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  if (isFetchingReasons) const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else ...reasons.map((reasonObj) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(reasonObj['reason'], style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () async { Navigator.pop(sheetContext); await _executeSafetyAction(profileId, reasonObj['id'], type); },
                      );
                    }),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _executeSafetyAction(String targetId, int reasonId, String type) async {
    setState(() => _isLoading = true);
    try {
      final options = await _getSecureOptions();
      final endpoint = type == 'block' ? '/block' : '/report';
      final payload = type == 'block' ? {'blocked_id': targetId, 'reason_id': reasonId} : {'reported_id': targetId, 'reason_id': reasonId};
      await dio.post('$apiUrl$endpoint', data: payload, options: options);

      if (_pageController.page != null && _pageController.page!.toInt() < _potentialMatches.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else {
        setState(() => _potentialMatches.clear());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(type == 'block' ? 'User blocked successfully.' : 'Report submitted successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to complete action.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSwipeAction(bool isLike, String profileId) async {
    try {
      final options = await _getSecureOptions();
      final response = await dio.post('$apiUrl/swipe', data: {'swiped_id': profileId, 'action': isLike ? 'like' : 'pass'}, options: options);

      if (response.data['isMatch'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ ZENITH ALIGNMENT! It\'s a Match! ✨', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1, color: Colors.white)), 
            backgroundColor: AppTheme.hotPink, 
            duration: Duration(seconds: 4), 
            behavior: SnackBarBehavior.floating
          )
        );
      }

      if (_pageController.page != null && _pageController.page!.toInt() < _potentialMatches.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else {
        setState(() => _potentialMatches.clear());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error. Try again.')));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.hotPink)));
    }

    if (_potentialMatches.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('DUVA', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(icon: const Icon(Icons.tune), onPressed: _showPreferencesSheet),
            IconButton(icon: const Icon(Icons.notifications_none), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 100, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                const SizedBox(height: 24),
                Text('No Alignments Found', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
                const SizedBox(height: 16),
                Text('We couldn\'t find anyone matching your current preferences. Try broadening your horizons.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5)),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity, 
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.tune, color: Colors.white), 
                    label: const Text('UPDATE PREFERENCES'), 
                    onPressed: _showPreferencesSheet
                  )
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.skySurge, AppTheme.hotPink]).createShader(bounds),
          child: const Text('DUVA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, letterSpacing: 2, color: Colors.white)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: _showPreferencesSheet),
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
        ],
      ),
      body: PageView.builder(
        controller: _pageController, 
        physics: const NeverScrollableScrollPhysics(), 
        itemCount: _potentialMatches.length,
        itemBuilder: (context, index) {
          return _buildPunchyProfileCard(_potentialMatches[index], colorScheme);
        }
      ),
    );
  }

  // --- THE PUNCHY PROFILE CARD ---
  Widget _buildPunchyProfileCard(MatchProfile profile, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0, top: 8.0),
      child: Container(
        // Outer Container creates the glowing gradient border
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [AppTheme.skySurge, AppTheme.hotPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: AppTheme.hotPink.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 10)),
            BoxShadow(color: AppTheme.skySurge.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -2, offset: const Offset(0, -10)),
          ]
        ),
        child: Container(
          // Inner container holds the actual content
          decoration: BoxDecoration(
            color: colorScheme.surface, 
            borderRadius: BorderRadius.circular(29), 
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (profile.images.isNotEmpty) 
                        Stack(
                          children: [
                            Image.network(profile.images[0], height: 500, width: double.infinity, fit: BoxFit.cover),
                            // Gradient overlay so text on image (if added later) is legible
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [colorScheme.surface, colorScheme.surface.withValues(alpha: 0)])
                                ),
                              ),
                            ),
                          ],
                        ),
                      
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${profile.firstName}, ${profile.age}', 
                                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: -0.5)
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 18, color: AppTheme.skySurge),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${profile.location} • ${profile.distance} km away', 
                                            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.w600)
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      
                                      // --- INTENSE DATE BID GRADIENT ---
                                      if (profile.currentDateBid != null && profile.currentDateBid!.isNotEmpty)
                                        Container(
                                          width: double.infinity, 
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [AppTheme.hotPink, AppTheme.skySurge], 
                                              begin: Alignment.topLeft, 
                                              end: Alignment.bottomRight
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(color: AppTheme.hotPink.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(Icons.local_fire_department, color: Colors.white, size: 22), 
                                                  SizedBox(width: 8), 
                                                  Text(
                                                    'ACTIVE DATE BID', 
                                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)
                                                  )
                                                ]
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                profile.currentDateBid!, 
                                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4)
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_horiz, color: colorScheme.onSurface.withValues(alpha: 0.6), size: 30),
                                  onSelected: (value) {
                                    _showSafetySheet(profile.id, profile.firstName, value);
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(value: 'block', child: Text('Block User')),
                                    const PopupMenuItem<String>(value: 'report', child: Text('Report User', style: TextStyle(color: AppTheme.hotPink, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                              ],
                            ),
                            
                            if (profile.sharedInterestsCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.skySurge.withValues(alpha: 0.15), 
                                    borderRadius: BorderRadius.circular(24), 
                                    border: Border.all(color: AppTheme.skySurge.withValues(alpha: 0.5), width: 1.5)
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min, 
                                    children: [
                                      const Icon(Icons.stars, size: 18, color: AppTheme.skySurge), 
                                      const SizedBox(width: 8), 
                                      Text(
                                        '${profile.sharedInterestsCount} Shared Interests', 
                                        style: const TextStyle(color: AppTheme.skySurge, fontWeight: FontWeight.w900, fontSize: 14)
                                      )
                                    ]
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      if (profile.bio != null && profile.bio!.isNotEmpty) 
                        _buildContentBlock('ABOUT ME', profile.bio!, colorScheme),
                      
                      if (profile.images.length > 1) 
                        Image.network(profile.images[1], height: 450, fit: BoxFit.cover),
                      
                      if (profile.interests.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'INTERESTS', 
                                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w900, letterSpacing: 1.2)
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10.0, 
                                runSpacing: 10.0,
                                children: profile.interests.map((interest) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: colorScheme.background.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.1))
                                    ),
                                    child: Text(
                                      interest,
                                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _buildDecisionActionBar(profile.id, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentBlock(String title, String content, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title, 
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: colorScheme.onSurface.withValues(alpha: 0.5))
          ),
          const SizedBox(height: 12),
          Text(
            content, 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.4, color: colorScheme.onSurface)
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionActionBar(String profileId, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 40.0),
      decoration: BoxDecoration(
        color: colorScheme.background.withValues(alpha: 0.8), // Glassy bottom bar
        border: Border(top: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.05)))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // GLOWING PASS BUTTON
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: FloatingActionButton(
              heroTag: 'pass_$profileId', 
              onPressed: () => _handleSwipeAction(false, profileId),
              backgroundColor: colorScheme.surface, 
              foregroundColor: Colors.redAccent, 
              elevation: 0,
              child: const Icon(Icons.close, size: 36),
            ),
          ),
          // GLOWING LIKE BUTTON
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.skySurge.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 10))],
            ),
            child: FloatingActionButton(
              heroTag: 'like_$profileId', 
              onPressed: () => _handleSwipeAction(true, profileId),
              backgroundColor: AppTheme.skySurge, 
              foregroundColor: colorScheme.background, 
              elevation: 0,
              child: const Icon(Icons.favorite, size: 36),
            ),
          ),
        ],
      ),
    );
  }
}