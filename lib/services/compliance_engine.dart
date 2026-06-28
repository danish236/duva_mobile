import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';
import '../legal/terms_and_conditions.dart';
import '../legal/privacy_policy.dart';
import '../legal/community_guidelines.dart';
import '../legal/cookie_policy.dart';

class ComplianceEngine {
  // POCSO & Age Compliance
  static const int minAge = 18;
  
  static bool isUserEligible(DateTime dob) {
    final now = DateTime.now();
    final adultDate = DateTime(dob.year + minAge, dob.month, dob.day);
    return now.isAfter(adultDate);
  }

  // Centralized Text Moderation
  static Future<bool> isTextClean(String text) async {
    if (text.trim().isEmpty) return true;
    
    final spamRegex = RegExp(r'(fuck|shit|bitch|cunt|nigger|onlyfans|only fans|t\.me|telegram|insta|ig:|snapchat|sc:|\@)', caseSensitive: false);
    if (spamRegex.hasMatch(text)) return false;

    try {
      final dio = ApiClient().dio;
      final apiUrl = ApiClient.apiUrl;
      final session = Supabase.instance.client.auth.currentSession;
      
      final response = await dio.post(
        '$apiUrl/moderate-text',
        data: {'text': text},
        options: Options(headers: {'Authorization': 'Bearer ${session?.accessToken}'}),
      );

      return response.data['isClean'] ?? true;
    } catch (e) {
      return true;
    }
  }

  // Legal Content Registry
  static Map<String, String> getLegalDocument(String docType) {
    switch (docType) {
      case 'terms':
        return {'title': TermsAndConditions.title, 'content': TermsAndConditions.content};
      case 'privacy':
        return {'title': PrivacyPolicy.title, 'content': PrivacyPolicy.content};
      case 'safety':
      case 'guidelines':
        return {'title': CommunityGuidelines.title, 'content': CommunityGuidelines.content};
      case 'cookie':
        return {'title': CookiePolicy.title, 'content': CookiePolicy.content};
      default:
        return {'title': 'INFO', 'content': 'No content available.'};
    }
  }
}
