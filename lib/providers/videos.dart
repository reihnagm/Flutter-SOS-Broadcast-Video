import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum ListenVStatus { idle, loading, loaded, empty, error }

class VideoProvider with ChangeNotifier {
  late VideoPlayerController? videoController;

  @override
  void dispose() {
    videoController!.dispose();
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

  void listenV(BuildContext context, [dynamic data]) {
    if(data != null) {
      videoController = VideoPlayerController.file(File(data["mediaUrl"]))
      ..addListener(() => notifyListeners())
      ..setLooping(false)
      ..initialize().then((_) => videoController!.pause());
      _v.add({
        "msg": data["message"],
        "mediaUrl": data["mediaUrl"]
      });
    }
    setStateListenVStatus(ListenVStatus.loaded);
    if(v.isEmpty) {
      setStateListenVStatus(ListenVStatus.empty);
    }
  }

}