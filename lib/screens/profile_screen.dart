import 'package:flutter/material.dart';

// ---------------------------------------------------------
// 1. DATA MODEL (Matches your Supabase Schema exactly)
// ---------------------------------------------------------
class ProfileData {
  final String firstName;
  final String lastName;
  final String location;
  final String? bio;
  final DateTime dob;
  final String? work;
  final String? education;
  final List<String> images; // From Cloudflare
  final String? expectations;
  final List<String> interests; // Joined from master_interests

  ProfileData({
    required this.firstName,
    required this.lastName,
    required this.location,
    this.bio,
    required this.dob,
    this.work,
    this.education,
    required this.images,
    this.expectations,
    required this.interests,
  });

  // Helper to calculate age from DOB
  int get age {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
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
  // Mock data representing what Hono will return from Supabase
  final ProfileData myProfile = ProfileData(
    firstName: 'Alex',
    lastName: 'Rivera',
    location: 'New York, NY',
    dob: DateTime(1996, 8, 14),
    bio: 'Just looking for someone to grab coffee with and explore the city.',
    work: 'Software Engineer at TechCorp',
    education: 'Columbia University',
    expectations: 'Long-term relationship, but let us start as friends.',
    interests: ['Coffee', 'Bouldering', 'Live Music', 'Photography'],
    images: [
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=800&auto=format&fit=crop', // Photo 1
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=800&auto=format&fit=crop', // Photo 2
      'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?q=80&w=800&auto=format&fit=crop', // Photo 3
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Slightly off-white background for contrast
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              // TODO: Navigate to settings to edit profile
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- PHOTO 1 ---
            if (myProfile.images.isNotEmpty)
              _buildFullWidthImage(myProfile.images[0]),

            // --- BASIC INFO CARD ---
            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${myProfile.firstName}, ${myProfile.age}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(myProfile.location, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (myProfile.work != null)
                    Row(
                      children: [
                        const Icon(Icons.work, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(myProfile.work!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  const SizedBox(height: 8),
                  if (myProfile.education != null)
                    Row(
                      children: [
                        const Icon(Icons.school, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(myProfile.education!, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                ],
              ),
            ),

            // --- BIO PROMPT ---
            if (myProfile.bio != null)
              _buildPromptCard('A bit about me...', myProfile.bio!),

            // --- PHOTO 2 ---
            if (myProfile.images.length > 1)
              _buildFullWidthImage(myProfile.images[1]),

            // --- EXPECTATIONS PROMPT ---
            if (myProfile.expectations != null)
              _buildPromptCard('What I am looking for', myProfile.expectations!),

            // --- INTERESTS WRAP ---
            _buildInfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Interests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8.0, // Gap between chips horizontally
                    runSpacing: 8.0, // Gap between chips vertically
                    children: myProfile.interests.map((interest) {
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

            // --- PHOTO 3 ---
            if (myProfile.images.length > 2)
              _buildFullWidthImage(myProfile.images[2]),
              
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  // Helper method to draw the images beautifully
  Widget _buildFullWidthImage(String imageUrl) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        imageUrl,
        height: 400,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(
            height: 400,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  // Helper method for standard info cards
  Widget _buildInfoCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // Helper method for text prompts (Hinge style)
  Widget _buildPromptCard(String promptTitle, String promptAnswer) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            promptTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            promptAnswer,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
          ),
        ],
      ),
    );
  }
}