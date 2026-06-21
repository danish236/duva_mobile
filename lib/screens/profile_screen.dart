import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart'; 

// ---------------------------------------------------------
// 1. DATA MODEL
// ---------------------------------------------------------
class ProfileData {
  final String id;
  final String firstName;
  final String lastName;
  final String location;
  final String? bio;
  final DateTime dob;
  final String? work;
  final String? education;
  final List<String> images; 
  final String? expectations;
  final String? currentDateBid; // <--- PROPERLY ADDED HERE
  final List<String> interests; 

  ProfileData({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.location,
    this.bio,
    required this.dob,
    this.work,
    this.education,
    required this.images,
    this.expectations,
    this.currentDateBid, // <--- PROPERLY ADDED HERE
    required this.interests,
  });

  int get age {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    List<String> parsedInterests = [];
    if (json['profile_interests'] != null) {
      for (var item in (json['profile_interests'] as List)) {
        if (item['master_interests'] != null && item['master_interests']['name'] != null) {
          parsedInterests.add(item['master_interests']['name'] as String);
        }
      }
    }

    return ProfileData(
      id: json['id'] ?? '',
      firstName: json['first_name'] ?? 'Unknown',
      lastName: json['last_name'] ?? '',
      location: json['location'] ?? 'Location not set',
      bio: json['bio'],
      dob: json['dob'] != null ? DateTime.parse(json['dob']) : DateTime.now(),
      work: json['work'],
      education: json['education'],
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      expectations: json['expectations'],
      currentDateBid: json['current_date_bid'], // <--- PROPERLY PARSED HERE
      interests: parsedInterests,
    );
  }
}

// ---------------------------------------------------------
// 2. THE UI SCREEN
// ---------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileData? _myProfile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User is not logged in.');

      final data = await Supabase.instance.client
          .from('profiles')
          .select('''
            *,
            profile_interests (
              master_interests ( name )
            )
          ''')
          .eq('id', userId)
          .single();

      setState(() {
        _myProfile = ProfileData.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Could not load profile. Have you completed onboarding?";
        _isLoading = false;
      });
      debugPrint('Profile Fetch Error: $e');
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_errorMessage != null || _myProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'Profile not found.', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _signOut, child: const Text('Sign Out'))
            ],
          ),
        ),
      );
    }

    final profile = _myProfile!;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.black),
            onPressed: () async {
              final didUpdate = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditProfileScreen(currentProfile: profile)),
              );
              if (didUpdate == true) {
                setState(() => _isLoading = true);
                _fetchMyProfile();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profile.images.isNotEmpty) _buildFullWidthImage(profile.images[0]),

            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.firstName}, ${profile.age}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(profile.location, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (profile.work != null && profile.work!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.work, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(profile.work!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (profile.education != null && profile.education!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.school, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(profile.education!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                ],
              ),
            ),

            // --- SHOW THE USER THEIR OWN DATE BID ---
            if (profile.currentDateBid != null && profile.currentDateBid!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF9A9E).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.local_activity, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('MY ACTIVE DATE BID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
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

            if (profile.bio != null && profile.bio!.isNotEmpty)
              _buildPromptCard('A bit about me...', profile.bio!),

            if (profile.images.length > 1) _buildFullWidthImage(profile.images[1]),

            if (profile.expectations != null && profile.expectations!.isNotEmpty)
              _buildPromptCard('What I am looking for', profile.expectations!),

            if (profile.interests.isNotEmpty)
              _buildInfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Interests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0, 
                      runSpacing: 8.0, 
                      children: profile.interests.map((interest) {
                        return Chip(
                          label: Text(interest),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[300]!),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            if (profile.images.length > 2) _buildFullWidthImage(profile.images[2]),
            const SizedBox(height: 40), 
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthImage(String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl, height: 400, fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(height: 400, child: Center(child: CircularProgressIndicator()));
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(height: 400, color: Colors.grey[300], child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)));
        },
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildPromptCard(String promptTitle, String promptAnswer) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(promptTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(promptAnswer, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3)),
        ],
      ),
    );
  }
}