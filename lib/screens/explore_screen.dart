import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_profile.dart'; 
import 'notifications_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String city = "Unknown Location";
      if (placemarks.isNotEmpty) {
        city = "${placemarks.first.locality}, ${placemarks.first.country}";
      }

      final options = await _getSecureOptions();
      await dio.post(
        '$apiUrl/location', 
        data: {'lat': position.latitude, 'lng': position.longitude, 'city': city},
        options: options
      );
      
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Future<Options> _getSecureOptions() async {
    final session = Supabase.instance.client.auth.currentSession;
    return Options(headers: {
      'Authorization': 'Bearer ${session?.accessToken}',
    });
  }

  Future<void> _fetchPool() async {
    try {
      final options = await _getSecureOptions();
      final response = await dio.get('$apiUrl/pool', options: options);
      
      final List<dynamic> data = response.data;
      setState(() {
        _potentialMatches = data.map((json) => MatchProfile.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching pool: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSafetySheet(String profileId, String profileName, String type) async {
    List<dynamic> reasons = [];
    bool isFetchingReasons = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            if (isFetchingReasons) {
              _getSecureOptions().then((options) {
                dio.get('$apiUrl/reasons?type=$type', options: options).then((response) {
                  setSheetState(() {
                    reasons = response.data;
                    isFetchingReasons = false;
                  });
                });
              });
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type == 'block' ? 'Block $profileName' : 'Report $profileName', 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: type == 'report' ? Colors.red : Colors.black)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type == 'block' ? 'They will no longer be able to see your profile or contact you.' : 'This will notify our Trust & Safety team. The user will also be blocked immediately.', 
                    style: const TextStyle(color: Colors.grey)
                  ),
                  const SizedBox(height: 24),

                  if (isFetchingReasons)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else
                    ...reasons.map((reasonObj) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(reasonObj['reason'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _executeSafetyAction(profileId, reasonObj['id'], type);
                        },
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
      final payload = type == 'block' 
          ? {'blocked_id': targetId, 'reason_id': reasonId}
          : {'reported_id': targetId, 'reason_id': reasonId};

      await dio.post('$apiUrl$endpoint', data: payload, options: options);

      if (_pageController.page != null && _pageController.page!.toInt() < _potentialMatches.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else {
        setState(() => _potentialMatches.clear());
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(type == 'block' ? 'User blocked successfully.' : 'Report submitted successfully.')),
      );
    } catch (e) {
      debugPrint("Safety Action Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to complete action.')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Discovery Preferences', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Age Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('${currentAgeRange.start.round()} - ${currentAgeRange.end.round()}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  RangeSlider(
                    values: currentAgeRange, min: 18, max: 65, divisions: 47, activeColor: Colors.blueAccent,
                    onChanged: (RangeValues values) { setSheetState(() => currentAgeRange = values); },
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Maximum Distance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('${currentDistance.round()} km', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: currentDistance, min: 5, max: 160, divisions: 31, activeColor: Colors.blueAccent,
                    onChanged: (value) => setSheetState(() => currentDistance = value),
                  ),
                  const SizedBox(height: 24),

                  const Text('Looking For', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true, value: selectedExpectation,
                        items: ['Any', 'Long-term relationship', 'Casual dating', 'New friends'].map((String value) {
                          return DropdownMenuItem<String>(value: value, child: Text(value));
                        }).toList(),
                        onChanged: (newValue) { setSheetState(() => selectedExpectation = newValue!); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: isSaving ? null : () async {
                        setSheetState(() => isSaving = true);
                        try {
                          final options = await _getSecureOptions();
                          await dio.post(
                            '$apiUrl/preferences', 
                            data: {
                              'min_age': currentAgeRange.start.round(), 
                              'max_age': currentAgeRange.end.round(), 
                              'max_distance': currentDistance.round(), 
                              'filter_expectation': selectedExpectation
                            }, 
                            options: options
                          );
                          
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext); 
                          
                          setState(() { _isLoading = true; _potentialMatches.clear(); });
                          _fetchPool();
                        } catch (e) {
                          debugPrint("Error saving preferences: $e");
                          setSheetState(() => isSaving = false);
                        }
                      },
                      child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Apply & Refresh Pool', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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

  Future<void> _handleSwipeAction(bool isLike, String profileId) async {
    try {
      final options = await _getSecureOptions();
      final response = await dio.post('$apiUrl/swipe', data: {'swiped_id': profileId, 'action': isLike ? 'like' : 'pass'}, options: options);

      if (response.data['isMatch'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ Zenith Alignment! It\'s a Match! ✨', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.purple, duration: Duration(seconds: 4), behavior: SnackBarBehavior.floating),
        );
      }

      if (_pageController.page != null && _pageController.page!.toInt() < _potentialMatches.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      } else {
        setState(() => _potentialMatches.clear());
      }
    } catch (e) {
      debugPrint("Swipe Error: $e");
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
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_potentialMatches.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Duva Pool', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 1,
          actions: [
            IconButton(icon: const Icon(Icons.tune, color: Colors.black), onPressed: _showPreferencesSheet),
            IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
            const SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 24),
                const Text('No Alignments Found', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 12),
                Text('We couldn\'t find anyone matching your current preferences. Try broadening your horizons to see more people.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.4)),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 2),
                    icon: const Icon(Icons.tune, color: Colors.white),
                    label: const Text('Update Preferences', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _showPreferencesSheet, 
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[200], 
      appBar: AppBar(
        title: const Text('Duva Pool', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.tune, color: Colors.black), onPressed: _showPreferencesSheet),
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))),
          const SizedBox(width: 8),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), 
        itemCount: _potentialMatches.length,
        itemBuilder: (context, index) {
          return _buildRichProfileCard(_potentialMatches[index]);
        },
      ),
    );
  }

  Widget _buildRichProfileCard(MatchProfile profile) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
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
                      Image.network(profile.images[0], height: 450, fit: BoxFit.cover),

                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Text & Location Info wrapped inside Expanded to avoid overflow and bracket errors
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${profile.firstName}, ${profile.age}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('${profile.location} • ${profile.distance} km away', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // --- NEW DATE BID UI ---
                                    if (profile.currentDateBid != null && profile.currentDateBid!.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(color: const Color(0xFFFF9A9E).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Row(
                                              children: [
                                                Icon(Icons.local_activity, color: Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text('ACTIVE DATE BID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              profile.currentDateBid!,
                                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // ------------------------
                                  ],
                                ),
                              ),
                              
                              // The 3 dots menu
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                                onSelected: (value) => _showSafetySheet(profile.id, profile.firstName, value),
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(value: 'block', child: Text('Block User')),
                                  const PopupMenuItem<String>(value: 'report', child: Text('Report User', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                          
                          if (profile.sharedInterestsCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purple.withValues(alpha: 0.3))),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min, 
                                  children: [
                                    const Icon(Icons.stars, size: 16, color: Colors.purple), const SizedBox(width: 6),
                                    Text('${profile.sharedInterestsCount} Shared Interests', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (profile.bio != null && profile.bio!.isNotEmpty) _buildContentBlock('A bit about me...', profile.bio!),
                    if (profile.images.length > 1) Image.network(profile.images[1], height: 400, fit: BoxFit.cover),
                    if (profile.expectations != null && profile.expectations!.isNotEmpty) _buildContentBlock('What I am looking for', profile.expectations!),
                    
                    if (profile.interests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Interests', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8.0, runSpacing: 8.0,
                              children: profile.interests.map((interest) {
                                return Chip(label: Text(interest), backgroundColor: Colors.blue[50], side: BorderSide.none);
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _buildDecisionActionBar(profile.id),
          ],
        ),
      ),
    );
  }

  Widget _buildContentBlock(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildDecisionActionBar(String profileId) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 40.0),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            heroTag: 'pass_$profileId', onPressed: () => _handleSwipeAction(false, profileId),
            backgroundColor: Colors.white, foregroundColor: Colors.redAccent, elevation: 2,
            child: const Icon(Icons.close, size: 32),
          ),
          FloatingActionButton(
            heroTag: 'like_$profileId', onPressed: () => _handleSwipeAction(true, profileId),
            backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, elevation: 4,
            child: const Icon(Icons.favorite, size: 32),
          ),
        ],
      ),
    );
  }
}