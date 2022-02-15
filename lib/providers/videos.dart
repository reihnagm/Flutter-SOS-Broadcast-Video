import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_broadcast_sos/utils/constant.dart';

enum ListenVStatus { idle, loading, loaded, empty, error }

class VideoProvider with ChangeNotifier {
  final SharedPreferences sharedPreferences;
  VideoProvider({
    required this.sharedPreferences
  });

  Future<String?> fetchFcm(BuildContext context) async {
    try {
      Dio dio = Dio();
      Response res = await dio.get('${AppConstants.baseUrl}/fetch-fcm');
      Map<String, dynamic> data = res.data;
      String fcm = data["fcm_secret"];
      return fcm;
    } on DioError catch(e) {
      if(e.response!.statusCode == 400 || e.response!.statusCode == 404 || e.response!.statusCode == 500 || e.response!.statusCode == 502) {
        debugPrint("(${e.response!.statusCode}) : Fetch FCM");
      }
    } catch(e) {
      debugPrint(e.toString());
    }
  }

  Future<String?> uploadVideo({required File file}) async {
    try {
      Dio dio = Dio();
      FormData formData = FormData.fromMap({
        "video": await MultipartFile.fromFile(
          file.path, 
          filename: basename(file.path)
        ),
      });
      Response res = await dio.post("http://cxid.xyz:3000/upload", data: formData);
      Map<String, dynamic> data = res.data;
      String url = data["url"];
      return url;
    } on DioError catch(e) {
      if(e.response!.statusCode == 400 || e.response!.statusCode == 404 || e.response!.statusCode == 500 || e.response!.statusCode == 502) {
        debugPrint("(${e.response!.statusCode}) : Upload Video");
      }
    } catch(e) {
      debugPrint(e.toString());
    } 
  }

}