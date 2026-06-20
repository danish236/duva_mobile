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
}