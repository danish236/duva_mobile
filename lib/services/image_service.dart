import 'dart:io';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageService {
  /// Compresses a File to WebP and uploads it securely to Cloudflare R2
  static Future<String?> compressAndUploadImage(File img, String userId, int index) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}_$index.webp';
    final targetPath = '${tempDir.path}/$fileName';

    // 1. Compress
    final XFile? compressedImage = await FlutterImageCompress.compressAndGetFile(
      img.absolute.path,
      targetPath,
      quality: 75,
      format: CompressFormat.webp,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (compressedImage == null) return null;

    // 2. Upload
    final String apiUrl = dotenv.env['BACKEND_URL'] ?? 'https://backend.duvamobile.workers.dev';
    
    // Use the alias here
    final dio = dio_pkg.Dio();
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null || session.accessToken == null) {
      throw Exception('User is not authenticated. Cannot upload image.');
    }

    // Use the alias for FormData and MultipartFile
    dio_pkg.FormData formData = dio_pkg.FormData.fromMap({
      'image': await dio_pkg.MultipartFile.fromFile(
        compressedImage.path, 
        filename: fileName
      ),
    });

    final response = await dio.post(
      '$apiUrl/upload',
      data: formData,
      // Use the alias for Options
      options: dio_pkg.Options(
        headers: {'Authorization': 'Bearer ${session.accessToken}'} // Safe to use directly now
      ),
    );

    if (response.statusCode == 200 && response.data['url'] != null) {
      return response.data['url'] as String;
    }
    
    throw Exception('Cloudflare Upload Failed');
  }
}