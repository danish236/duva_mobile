import 'package:flutter/material.dart';

class MatchProfile {
  final String id;
  final String firstName;
  final int age;
  final String location;
  final int distance;
  final String? bio;
  final String? expectations;
  final String? work;
  final String? education;
  final String? currentDateBid;
  final List<String> interests;
  final List<String> images;
  final int sharedInterestsCount;
  final DateTime? lastSeen; // 🟢 NEW

  const MatchProfile({
    required this.id,
    required this.firstName,
    required this.age,
    required this.location,
    this.distance = 0,
    this.bio,
    this.expectations,
    this.work,
    this.education,
    this.currentDateBid,
    required this.interests,
    required this.images,
    this.sharedInterestsCount = 0,
    this.lastSeen,
  });

  factory MatchProfile.fromJson(Map<String, dynamic> json) {
    return MatchProfile(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? 'Unknown',
      age: json['age'] ?? 18,
      location: json['location'] ?? 'Unknown Location',
      distance: json['distance'] ?? 0,
      bio: json['bio'],
      expectations: json['expectations'],
      work: json['work'],
      education: json['education'],
      currentDateBid: json['currentDateBid'],
      interests: json['interests'] != null ? List<String>.from(json['interests']) : [],
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      sharedInterestsCount: json['sharedInterestsCount'] ?? 0,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'age': age,
      'location': location,
      'distance': distance,
      'bio': bio,
      'expectations': expectations,
      'work': work,
      'education': education,
      'currentDateBid': currentDateBid,
      'interests': interests,
      'images': images,
      'sharedInterestsCount': sharedInterestsCount,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  // --- 🟢 GHOSTING RADAR LOGIC ---

  String get activeStatusText {
    if (lastSeen == null) return 'Recently';
    final diff = DateTime.now().difference(lastSeen!);

    if (diff.inMinutes < 20) return 'Active Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays <= 3) return '${diff.inDays}d ago';
    return 'Hibernating';
  }

  Color get activeStatusColor {
    if (lastSeen == null) return Colors.white38;
    final diff = DateTime.now().difference(lastSeen!);

    if (diff.inMinutes < 20) return const Color(0xFF00FF66); // Neon Green
    if (diff.inHours < 24) return const Color(0xFF00E5FF); // Electric Cyan
    if (diff.inDays <= 3) return Colors.amber; // Warning Yellow
    return Colors.white38; // Hibernating Grey
  }
}