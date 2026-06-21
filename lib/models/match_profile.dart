class MatchProfile {
  final String id;
  final String firstName;
  final int age;
  final String location;
  final String? bio;
  final String? expectations;
  final String? work;
  final String? education;
  final List<String> interests;
  final List<String> images;
  final int sharedInterestsCount; // New Field

  const MatchProfile({
    required this.id,
    required this.firstName,
    required this.age,
    required this.location,
    this.bio,
    this.expectations,
    this.work,
    this.education,
    required this.interests,
    required this.images,
    this.sharedInterestsCount = 0,
  });

  factory MatchProfile.fromJson(Map<String, dynamic> json) {
    return MatchProfile(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? 'Unknown',
      age: json['age'] ?? 18,
      location: json['location'] ?? 'Unknown Location',
      bio: json['bio'],
      expectations: json['expectations'],
      work: json['work'],
      education: json['education'],
      interests: json['interests'] != null ? List<String>.from(json['interests']) : [],
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      sharedInterestsCount: json['sharedInterestsCount'] ?? 0,
    );
  }
}