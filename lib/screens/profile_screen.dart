import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart'; 
import '../theme.dart';
import '../widgets/premium_shimmer.dart';
import '../services/cache_service.dart';
import '../messages.dart';
import '../constants.dart';

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
  
  final String? height;
  final String? weight;
  final String? smoking;
  final String? drinking;
  final String? workout;
  final String? pets;
  final String? zodiac;
  final String? kids;
  final bool isPremium;

  ProfileData({
    required this.id, required this.firstName, required this.lastName, required this.location, 
    this.bio, required this.dob, this.work, this.education, required this.images, 
    this.expectations, this.currentDateBid, required this.interests,
    this.height, this.weight, this.smoking, this.drinking, this.workout, this.pets, this.zodiac, this.kids,
    this.isPremium = false,
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
      weight: json['weight']?.toString(), // Safely parse int or string
      smoking: json['smoking'],
      drinking: json['drinking'],
      workout: json['workout'],
      pets: json['pets'],
      zodiac: json['zodiac'],
      kids: json['kids'],
      isPremium: json['is_premium'] ?? false,
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
      if (userId == null) throw Exception(Messages.profileNotLoggedIn);
      final data = await CacheService().getOrFetch<Map<String, dynamic>>(
        'profile_data',
        () async {
          final result = await Supabase.instance.client.from('profiles').select('*, profile_interests (master_interests ( name ))').eq('id', userId).single();
          return Map<String, dynamic>.from(result);
        },
        ttl: AppConstants.cacheTtlProfile,
      );
      setState(() { _myProfile = ProfileData.fromJson(data); _isLoading = false; });
    } catch (e) {
      setState(() { _errorMessage = Messages.couldNotLoadProfile; _isLoading = false; });
    }
  }

  bool _isValid(String? val) => val != null && val.trim().isNotEmpty && val != 'null';

  double _profileCompletion(ProfileData p) {
    int filled = 0;
    int total = 0;
    if (p.images.isNotEmpty) filled++; total++;
    if (_isValid(p.bio)) filled++; total++;
    if (_isValid(p.work)) filled++; total++;
    if (_isValid(p.education)) filled++; total++;
    if (_isValid(p.expectations)) filled++; total++;
    if (p.interests.isNotEmpty) filled++; total++;
    if (_isValid(p.height)) filled++; total++;
    if (_isValid(p.weight)) filled++; total++;
    if (_isValid(p.smoking)) filled++; total++;
    if (_isValid(p.drinking)) filled++; total++;
    if (_isValid(p.workout)) filled++; total++;
    if (_isValid(p.pets)) filled++; total++;
    if (_isValid(p.zodiac)) filled++; total++;
    if (_isValid(p.kids)) filled++; total++;
    if (_isValid(p.currentDateBid)) filled++; total++;
    return total == 0 ? 0.0 : filled / total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.voidBackground,
        appBar: AppBar(
          title: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
                child: Image.asset('assets/logo_nobg.png', height: 28, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(Messages.profileTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5, color: Colors.white)),
            ],
          ),
        ),
        body: const PremiumShimmer(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShimmerBox(width: double.infinity, height: 450, borderRadius: 32), // Main Image
                SizedBox(height: 16),
                ShimmerBox(width: double.infinity, height: 160, borderRadius: 32), // Info Card
                SizedBox(height: 16),
                ShimmerBox(width: double.infinity, height: 100, borderRadius: 32), // Date Bid
                SizedBox(height: 16),
                ShimmerBox(width: double.infinity, height: 180, borderRadius: 32), // Lifestyle
              ],
            ),
          ),
        ),
      );
    }
    

    if (_errorMessage != null || _myProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MY PROFILE')),
        body: Center(child: Text(_errorMessage ?? 'Profile not found.', style: const TextStyle(color: Colors.white))),
      );
    }

    final profile = _myProfile!;
    
    // Hardened logic to prevent empty boxes or null text
    final lifestyleTags = [
      if (_isValid(profile.height)) {'icon': Icons.height, 'value': profile.height},
      if (_isValid(profile.weight)) {'icon': Icons.fitness_center, 'value': '${profile.weight} kg'},
      if (_isValid(profile.zodiac)) {'icon': Icons.auto_awesome, 'value': profile.zodiac},
      if (_isValid(profile.workout)) {'icon': Icons.directions_run, 'value': profile.workout},
      if (_isValid(profile.smoking)) {'icon': Icons.smoking_rooms, 'value': profile.smoking},
      if (_isValid(profile.drinking)) {'icon': Icons.local_bar, 'value': profile.drinking},
      if (_isValid(profile.pets)) {'icon': Icons.pets, 'value': profile.pets},
      if (_isValid(profile.kids)) {'icon': Icons.face, 'value': profile.kids},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
              child: Image.asset('assets/logo_nobg.png', height: 28, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text(Messages.profileTitle, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5, color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.white),
            onPressed: () async {
              final didUpdate = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(currentProfile: profile)));
              if (didUpdate == true) {
                CacheService().remove('profile_data');
                CacheService().remove('is_premium');
                setState(() => _isLoading = true);
                _fetchMyProfile();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.electricCyan,
        backgroundColor: const Color(0xFF1A1A1A),
        onRefresh: () async {
          CacheService().remove('profile_data');
          CacheService().remove('is_premium');
          setState(() => _isLoading = true);
          await _fetchMyProfile();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile.images.isNotEmpty) _buildFullWidthImage(profile.images[0]),

              _buildPunchyInfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${profile.firstName}, ${profile.age}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                        if (profile.isPremium) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: AppTheme.electricCyan.withValues(alpha: 0.3), blurRadius: 8)],
                            ),
                            child: const Text(Messages.premiumBadge, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: [const Icon(Icons.location_on, size: 18, color: AppTheme.electricCyan), const SizedBox(width: 6), Text(profile.location, style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600))]),
                    if (_isValid(profile.work)) Padding(padding: const EdgeInsets.only(top: 8.0), child: Row(children: [const Icon(Icons.work, size: 18, color: AppTheme.primaryRose), const SizedBox(width: 6), Text(profile.work!, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600))])),
                    if (_isValid(profile.education)) Padding(padding: const EdgeInsets.only(top: 8.0), child: Row(children: [const Icon(Icons.school, size: 18, color: AppTheme.electricCyan), const SizedBox(width: 6), Text(profile.education!, style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600))])),
                  ],
                ),
              ),

              // Profile completion bar
              _buildCompletionBar(profile),

            if (_isValid(profile.currentDateBid))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.local_fire_department, color: Colors.white, size: 22), SizedBox(width: 8), Text(Messages.myActiveDateBid, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13))]),
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
                decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Messages.profileLifestyle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.5))),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10.0, runSpacing: 10.0, 
                      children: lifestyleTags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: AppTheme.voidBackground, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(tag['icon'] as IconData, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Text(tag['value'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            if (_isValid(profile.bio)) _buildPunchyPromptCard(Messages.aboutMe, profile.bio!),
            if (profile.images.length > 1) _buildFullWidthImage(profile.images[1]),
            if (_isValid(profile.expectations)) _buildPunchyPromptCard(Messages.lookingFor, profile.expectations!),
            
            if (profile.interests.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Messages.interests, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white.withValues(alpha: 0.5))),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10.0, runSpacing: 10.0, 
                      children: profile.interests.map((interest) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: AppTheme.electricCyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.electricCyan.withValues(alpha: 0.3))),
                          child: Text(interest, style: const TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.w800, fontSize: 14)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            if (profile.images.length > 2) _buildFullWidthImage(profile.images[2]),
            const SizedBox(height: 120),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCompletionBar(ProfileData p) {
    final double completion = _profileCompletion(p);
    final int pct = (completion * 100).round();
    final bool isComplete = completion >= 1.0;
    final String label = isComplete ? 'Profile Complete!' : '$pct% Complete';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isComplete ? AppTheme.electricCyan.withValues(alpha: 0.3) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isComplete ? Icons.check_circle : Icons.person_outline, size: 18, color: isComplete ? AppTheme.electricCyan : AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(color: isComplete ? AppTheme.electricCyan : AppTheme.textSecondary, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
                ],
              ),
              if (!isComplete)
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(currentProfile: p)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.primaryRose, borderRadius: BorderRadius.circular(12)),
                    child: const Text(Messages.fillProfile, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completion,
              backgroundColor: AppTheme.voidBackground,
              valueColor: AlwaysStoppedAnimation<Color>(isComplete ? AppTheme.electricCyan : AppTheme.primaryRose),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthImage(String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32), // Deep, continuous curve
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))]
      ),
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
      decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white12)),
      child: child,
    );
  }

  Widget _buildPunchyPromptCard(String promptTitle, String promptAnswer) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white12)),
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