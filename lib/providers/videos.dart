import 'package:flutter/material.dart';
import 'package:stream_broadcast_sos/services/sqlite.dart';
import 'package:video_player/video_player.dart';

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

  final List _v = [];
  List get v => [..._v]; 

  ListenVStatus _listenVStatus = ListenVStatus.idle;
  ListenVStatus get listenVStatus => _listenVStatus; 

  void setStateListenVStatus(ListenVStatus listenVStatus) {
    _listenVStatus = listenVStatus;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  Future<void> listenV(BuildContext context, [dynamic data]) async {
    setStateListenVStatus(ListenVStatus.loading);
    if(data != null) {
      await DBHelper.insert("sos", {
        "id": data["id"],
        "mediaUrl": data["mediaUrl"],
        "msg": data["msg"]
      });
      _v.insert(0, {
        "id": data["id"],
        "video": VideoPlayerController.network(data["mediaUrl"])
        ..addListener(() => notifyListeners())
        ..setLooping(false)
        ..initialize(),
        "msg": data["msg"],
      });
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
      _v.addAll(sosAssign);
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
      setStateListenVStatus(ListenVStatus.loaded);
    } catch(e) {
      debugPrint(e.toString());
    }
  }

}