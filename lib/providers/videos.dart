import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:video_player/video_player.dart';

import 'package:stream_broadcast_sos/services/sqlite.dart';

enum ListenVStatus { idle, loading, loaded, empty, error }

class VideoProvider with ChangeNotifier {

  @override
  void dispose() {
    for (var vi in v) {
      VideoPlayerController vpc = vi["video"];
      vpc.dispose(); 
    }
    super.dispose();
  }

  List _v = [];
  List get v => [..._v]; 

  ListenVStatus _listenVStatus = ListenVStatus.idle;
  ListenVStatus get listenVStatus => _listenVStatus; 

  void setStateListenVStatus(ListenVStatus listenVStatus) {
    _listenVStatus = listenVStatus;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  Future<void> listenV(BuildContext context, [dynamic data]) async {
    _v = [];
    setStateListenVStatus(ListenVStatus.loading);
    if(data != null) {
      await DBHelper.insert("sos", {
        "id": data["id"],
        "mediaUrl": data["mediaUrl"],
        "msg": data["msg"]
      });
      List<Map<String, dynamic>> listSos = await DBHelper.fetchSos(context);
      for (var sos in listSos) {
        _v.add({
          "id": sos["id"],
          "video": VideoPlayerController.network(sos["mediaUrl"])
          ..addListener(() => notifyListeners())
          ..setLooping(false)
          ..initialize(),
          "msg": sos["msg"],
        });
      }
    } else {
      List<Map<String, dynamic>> listSos = await DBHelper.fetchSos(context);
      List<Map<String, dynamic>> sosAssign = [];
      for (var sos in listSos) {
        sosAssign.add({
          "id": sos["id"],
          "video": VideoPlayerController.network(sos["mediaUrl"])
          ..addListener(() => notifyListeners())
          ..setLooping(false)
          ..initialize(),
          "msg":sos["msg"],
        });
      }
      _v = sosAssign;
    }
    setStateListenVStatus(ListenVStatus.loaded);
    if(v.isEmpty) {
      setStateListenVStatus(ListenVStatus.empty);
    }
  }

  Future<void> deleteV(BuildContext context, {required String id}) async {
    try {
      await DBHelper.delete("sos", id);
      _v.removeWhere((el) => el["id"] == id);
      Future.delayed(Duration.zero, () => notifyListeners());
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