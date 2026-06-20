import 'package:flutter/material.dart';
import '../models/match_profile.dart'; // Import your new model

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // PageController manages the horizontal swiping between users
  final PageController _pageController = PageController();

  // Mock Data: This will later be populated via your Hono.js/Supabase API
  final List<MatchProfile> _potentialMatches = [
    const MatchProfile(
      id: 'usr_1',
      firstName: 'Sarah',
      age: 26,
      location: 'Mumbai, India',
      bio: 'Looking for someone to argue about movies with.',
      expectations: 'Long-term relationship, mutual growth.',
      interests: ['Cinematography', 'Sushi', 'Travel', 'Indie Music'],
      images: [
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?q=80&w=800&auto=format&fit=crop',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=800&auto=format&fit=crop',
      ],
    ),
    const MatchProfile(
      id: 'usr_2',
      firstName: 'Rohan',
      age: 28,
      location: 'Pune, India',
      bio: 'Software dev by day, amateur chef by night.',
      expectations: 'Casual dating leading to something serious.',
      interests: ['Cooking', 'Tech', 'Dogs', 'Hiking'],
      images: [
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=800&auto=format&fit=crop',
      ],
    ),
  ];

  /// Handles the action of liking or passing a profile, then advances the feed
  void _handleSwipeAction(bool isLike, String profileId) {
    // TODO: Send background request to Hono.js/Supabase to log the swipe
    print(isLike ? 'Liked $profileId' : 'Passed $profileId');

    // Move to the next profile in the feed smoothly
    if (_pageController.page != null &&
        _pageController.page!.toInt() < _potentialMatches.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Out of matches for the day (Ties into your 3-matches/24hr freemium model)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have viewed all your daily matches!')),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
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
                    if (profile.bio != null)
                      _buildContentBlock('A bit about me...', profile.bio!),

                    // Photo 2
                    if (profile.images.length > 1)
                      Image.network(profile.images[1], height: 400, fit: BoxFit.cover),

                    // Expectations Prompt
                    if (profile.expectations != null)
                      _buildContentBlock('What I am looking for', profile.expectations!),

                    // Interests Wrap
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