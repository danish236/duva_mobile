/// Represents a potential match in the Explore feed.
/// Immutable data class adhering to clean architecture principles.
class MatchProfile {
  final String id;
  final String firstName;
  final int age;
  final String location;
  final String? bio;
  final String? expectations;
  final List<String> interests;
  final List<String> images;

  const MatchProfile({
    required this.id,
    required this.firstName,
    required this.age,
    required this.location,
    this.bio,
    this.expectations,
    required this.interests,
    required this.images,
  });

  factory MatchProfile.fromJson(Map<String, dynamic> json) {
  return MatchProfile(
    id: json['id'],
    firstName: json['first_name'],
    age: json['age'],
    location: json['location'],
    interests: List<String>.from(json['interests']),
    images: List<String>.from(json['images']),
  );
}
}
