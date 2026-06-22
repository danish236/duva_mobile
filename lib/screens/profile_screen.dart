import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart'; 
import '../theme.dart';

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
  
  // New Lifestyle Params
  final String? height;
  final String? weight;
  final String? smoking;
  final String? drinking;
  final String? workout;
  final String? pets;
  final String? zodiac;
  final String? kids;

  ProfileData({
    required this.id, required this.firstName, required this.lastName, required this.location, 
    this.bio, required this.dob, this.work, this.education, required this.images, 
    this.expectations, this.currentDateBid, required this.interests,
    this.height, this.weight, this.smoking, this.drinking, this.workout, this.pets, this.zodiac, this.kids
  });

  int get age {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
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
      height: json['height'],
      weight: json['weight'] != null ? json['weight'].toString() : null,
      smoking: json['smoking'],
      drinking: json['drinking'],
      workout: json['workout'],
      pets: json['pets'],
      zodiac: json['zodiac'],
      kids: json['kids'],
    );
  }
}

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
      final data = await Supabase.instance.client.from('profiles').select('*, profile_interests (master_interests ( name ))').eq('id', userId).single();
      setState(() { _myProfile = ProfileData.fromJson(data); _isLoading = false; });
    } catch (e) {
      setState(() { _errorMessage = "Could not load profile. Have you completed onboarding?"; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryRose)));

    if (_errorMessage != null || _myProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MY PROFILE')),
        body: Center(child: Text(_errorMessage ?? 'Profile not found.', style: const TextStyle(color: Colors.white))),
      );
    }

    final profile = _myProfile!;
    
    // Compile lifestyle tags dynamically
    final lifestyleTags = [
      if (profile.height != null) {'icon': Icons.height, 'value': profile.height},
      if (profile.weight != null) {'icon': Icons.monitor_weight, 'value': '${profile.weight} kg'},
      if (profile.zodiac != null) {'icon': Icons.star_border, 'value': profile.zodiac},
      if (profile.workout != null) {'icon': Icons.fitness_center, 'value': profile.workout},
      if (profile.smoking != null) {'icon': Icons.smoking_rooms, 'value': profile.smoking},
      if (profile.drinking != null) {'icon': Icons.local_bar, 'value': profile.drinking},
      if (profile.pets != null) {'icon': Icons.pets, 'value': profile.pets},
      if (profile.kids != null) {'icon': Icons.child_care, 'value': profile.kids},
    ];

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
          child: const Text('MY PROFILE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 1.5, color: Colors.white)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.white),
            onPressed: () async {
              final didUpdate = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(currentProfile: profile)));
              if (didUpdate == true) { setState(() => _isLoading = true); _fetchMyProfile(); }
            },
          ),
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profile.images.isNotEmpty) _buildFullWidthImage(profile.images[0]),

            _buildPunchyInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${profile.firstName}, ${profile.age}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 12),
                  Row(children: [const Icon(Icons.location_on, size: 18, color: AppTheme.electricCyan), const SizedBox(width: 6), Text(profile.location, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.w600))]),
                  if (profile.work != null && profile.work!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0), child: Row(children: [const Icon(Icons.work, size: 18, color: AppTheme.primaryRose), const SizedBox(width: 6), Text(profile.work!, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.w600))])),
                  if (profile.education != null && profile.education!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0), child: Row(children: [const Icon(Icons.school, size: 18, color: AppTheme.electricCyan), const SizedBox(width: 6), Text(profile.education!, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.w600))])),
                ],
              ),
            ),

            if (profile.currentDateBid != null && profile.currentDateBid!.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.local_fire_department, color: Colors.white, size: 22), SizedBox(width: 8), Text('MY ACTIVE DATE BID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13))]),
                    const SizedBox(height: 12),
                    Text(profile.currentDateBid!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4)),
                  ],
                ),
              ),

            // LIFESTYLE TAGS
            if (lifestyleTags.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LIFESTYLE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.5))),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10.0, runSpacing: 10.0, 
                      children: lifestyleTags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tag['icon'] as IconData, size: 14, color: AppTheme.electricCyan),
                              const SizedBox(width: 6),
                              Text(tag['value'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            if (profile.bio != null && profile.bio!.isNotEmpty) _buildPunchyPromptCard('ABOUT ME', profile.bio!),
            if (profile.images.length > 1) _buildFullWidthImage(profile.images[1]),
            if (profile.expectations != null && profile.expectations!.isNotEmpty) _buildPunchyPromptCard('LOOKING FOR', profile.expectations!),
            
            if (profile.interests.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INTERESTS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.5))),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10.0, runSpacing: 10.0, 
                      children: profile.interests.map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: AppTheme.electricCyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.electricCyan.withValues(alpha: 0.3))),
                          child: Text(interest, style: const TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.bold, fontSize: 14)),
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
      margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))]),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl, height: 450, fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(height: 450, child: Center(child: CircularProgressIndicator(color: AppTheme.electricCyan)));
        },
      ),
    );
  }

  Widget _buildPunchyInfoCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
      child: child,
    );
  }

  Widget _buildPunchyPromptCard(String promptTitle, String promptAnswer) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(promptTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 12),
          Text(promptAnswer, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.4, color: Colors.white)),
        ],
      ),
    );
  }
}