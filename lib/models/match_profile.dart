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
  final int sharedInterestsCount; // New Field

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
    );
  }

  // ✅ ADDED THIS METHOD TO RESOLVE THE COMPILER ERROR
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
    };
  }
}