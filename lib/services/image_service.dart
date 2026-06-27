import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import '../messages.dart';
import 'api_service.dart';

class ImageService {
  static Future<String?> compressAndUploadImage(File img, String userId, int index) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}_$index.webp';
    final targetPath = '${tempDir.path}/$fileName';

    final XFile? compressedImage = await FlutterImageCompress.compressAndGetFile(
      img.absolute.path,
      targetPath,
      quality: 75,
      format: CompressFormat.webp,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (compressedImage == null) return null;

    try {
      final dio = ApiClient().dio;
      final String apiUrl = ApiClient.apiUrl;

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final expiresAt = session.expiresAt ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (expiresAt - now < 60) {
          try { await Supabase.instance.client.auth.refreshSession(); } catch (_) {}
        }
      }

      final currentSession = Supabase.instance.client.auth.currentSession;
      if (currentSession == null) {
        throw Exception(Messages.userNotAuthenticated);
      }

      final FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          compressedImage.path,
          filename: fileName
        ),
      });

      final response = await dio.post(
        '$apiUrl/upload',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer ${currentSession.accessToken}'}
        ),
      );

      if (response.statusCode == 200 && response.data['url'] != null) {
        return response.data['url'] as String;
      }

      final aiRaw = response.data?['ai_raw'];
      final errMsg = response.data?['error'] ?? Messages.cloudflareUploadFailed;
      if (aiRaw != null) throw Exception('$errMsg (AI: $aiRaw)');
      throw Exception(errMsg);
    } finally {
      try { File(compressedImage.path).deleteSync(); } catch (_) {}
    }
  }
}
