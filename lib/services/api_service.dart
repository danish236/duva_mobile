import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/match_profile.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: dotenv.get('BACKEND_URL'), // Add this to your .env file!
  ));

  Future<List<MatchProfile>> fetchMatches() async {
    try {
      final response = await _dio.get('/pool'); // Your Hono endpoint
      // Map the JSON list to a list of MatchProfile objects
      return (response.data as List)
          .map((item) => MatchProfile.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to load matches');
    }
  }
}