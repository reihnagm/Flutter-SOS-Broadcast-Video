
import 'dart:io';

import 'package:video_compress/video_compress.dart';

class VideoServices {

  static Future<MediaInfo?> compressVideo(File file) async {
    try {
      await VideoCompress.setLogLevel(0);
      return await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.Res1280x720Quality,
        includeAudio: true, 
      );
    } catch(e) {
      VideoCompress.cancelCompression();
    }
  }

}