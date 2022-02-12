import 'package:get_it/get_it.dart';
import 'package:stream_video/providers/network.dart';
import 'package:stream_video/providers/videos.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  getIt.registerFactory(() => NetworkProvider());
  getIt.registerFactory(() => VideoProvider());
}