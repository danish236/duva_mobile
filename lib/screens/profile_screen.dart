import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart'; 
import '../theme.dart';

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
  final String? currentDateBid; 
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
    this.currentDateBid, 
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
      currentDateBid: json['current_date_bid'], 
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
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator(color: colorScheme.primary)));

    if (_errorMessage != null || _myProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'Profile not found.', style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _signOut, child: const Text('Sign Out'))
            ],
          ),
        ),
      );
    }

    final profile = _myProfile!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
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
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
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
              colorScheme: colorScheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.firstName}, ${profile.age}',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16.0, 
                    runSpacing: 8.0, 
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(profile.location, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
                        ],
                      ),
                      if (profile.work != null && profile.work!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.work, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text(profile.work!, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
                          ],
                        ),
                      if (profile.education != null && profile.education!.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text(profile.education!, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            if (profile.currentDateBid != null && profile.currentDateBid!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.hotPink, AppTheme.skySurge],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.hotPink.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
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
              _buildPromptCard('A bit about me...', profile.bio!, colorScheme),

            if (profile.images.length > 1) _buildFullWidthImage(profile.images[1]),

            if (profile.expectations != null && profile.expectations!.isNotEmpty)
              _buildPromptCard('What I am looking for', profile.expectations!, colorScheme),

            if (profile.interests.isNotEmpty)
              _buildInfoCard(
                colorScheme: colorScheme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Interests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0, 
                      runSpacing: 8.0, 
                      children: profile.interests.map((interest) {
                        return Chip(
                          label: Text(interest),
                          backgroundColor: colorScheme.background,
                          side: BorderSide.none,
                          labelStyle: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
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

  Widget _buildInfoCard({required Widget child, required ColorScheme colorScheme}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildPromptCard(String promptTitle, String promptAnswer, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(promptTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Text(promptAnswer, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}