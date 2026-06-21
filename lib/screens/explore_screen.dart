import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_profile.dart'; 

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // PageController manages the horizontal swiping between users
  final PageController _pageController = PageController();
  List<MatchProfile> _potentialMatches = [];
  bool _isLoading = true;
  final dio = Dio();

  // Your deployed Cloudflare URL
  final String apiUrl = 'https://backend.duvamobile.workers.dev';

  @override
  void initState() {
    super.initState();
    _fetchPool();
  }

  // --- GET SECURE HEADERS ---
  // This grabs the Supabase JWT token so the Edge API knows who is swiping
  Future<Options> _getSecureOptions() async {
    final session = Supabase.instance.client.auth.currentSession;
    return Options(headers: {
      'Authorization': 'Bearer ${session?.accessToken}',
    });
  }

  // --- FETCH USERS ---
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

  /// Handles the action of liking or passing a profile, then advances the feed
  Future<void> _handleSwipeAction(bool isLike, String profileId) async {
    try {
      final options = await _getSecureOptions();
      
      // 1. Send the background request to Hono to log the swipe
      final response = await dio.post(
        '$apiUrl/swipe',
        data: {
          'swiped_id': profileId,
          'action': isLike ? 'like' : 'pass'
        },
        options: options,
      );

      // 2. Check for mutual match (Zenith Alignment)
      if (response.data['isMatch'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Zenith Alignment! It\'s a Match! ✨', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 3. Move to the next profile in the feed smoothly
      if (_pageController.page != null &&
          _pageController.page!.toInt() < _potentialMatches.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        // Out of matches for the day
        setState(() {
          _potentialMatches.clear(); 
        });
      }
    } catch (e) {
      debugPrint("Swipe Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while fetching the pool from Cloudflare
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show empty state if there are no matches returned
    if (_potentialMatches.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: const Text('Duva Pool', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        body: const Center(
          child: Text("You're out of matches for today!", style: TextStyle(fontSize: 18, color: Colors.grey)),
        ),
      );
    }

    // Render the standard feed
    return Scaffold(
      backgroundColor: Colors.grey[200], // Distinct background to pop the cards
      appBar: AppBar(
        title: const Text('Duva Pool', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Forces users to use the action buttons
        itemCount: _potentialMatches.length,
        itemBuilder: (context, index) {
          return _buildRichProfileCard(_potentialMatches[index]);
        },
      ),
    );
  }

  /// Extracts the complex UI building into a clean, private helper method
  Widget _buildRichProfileCard(MatchProfile profile) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // Scrollable Profile Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photo 1 (Hero Image)
                    if (profile.images.isNotEmpty)
                      Image.network(profile.images[0], height: 450, fit: BoxFit.cover),

                    // Basic Info Nameplate
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile.firstName}, ${profile.age}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(profile.location, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Bio Prompt
                    if (profile.bio != null && profile.bio!.isNotEmpty)
                      _buildContentBlock('A bit about me...', profile.bio!),

                    // Photo 2
                    if (profile.images.length > 1)
                      Image.network(profile.images[1], height: 400, fit: BoxFit.cover),

                    // Expectations Prompt
                    if (profile.expectations != null && profile.expectations!.isNotEmpty)
                      _buildContentBlock('What I am looking for', profile.expectations!),

                    // Interests Wrap
                    if (profile.interests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Interests', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: profile.interests.map((interest) {
                                return Chip(
                                  label: Text(interest),
                                  backgroundColor: Colors.blue[50],
                                  side: BorderSide.none,
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

            // Fixed Action Bar (Accept/Reject)
            _buildDecisionActionBar(profile.id),
          ],
        ),
      ),
    );
  }

  /// Standardized text block component for prompts
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

  /// The bottom fixed bar containing the Match/Pass buttons
  Widget _buildDecisionActionBar(String profileId) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 40.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pass Button
          FloatingActionButton(
            heroTag: 'pass_$profileId',
            onPressed: () => _handleSwipeAction(false, profileId),
            backgroundColor: Colors.white,
            foregroundColor: Colors.redAccent,
            elevation: 2,
            child: const Icon(Icons.close, size: 32),
          ),
          // Like Button
          FloatingActionButton(
            heroTag: 'like_$profileId',
            onPressed: () => _handleSwipeAction(true, profileId),
            backgroundColor: Colors.blueAccent, // Duva primary brand color
            foregroundColor: Colors.white,
            elevation: 4,
            child: const Icon(Icons.favorite, size: 32),
          ),
        ],
      ),
    );
  }
}