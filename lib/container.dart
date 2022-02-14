import 'package:get_it/get_it.dart';
import 'package:stream_broadcast_sos/providers/network.dart';
import 'package:stream_broadcast_sos/providers/videos.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  getIt.registerFactory(() => NetworkProvider());
  getIt.registerFactory(() => VideoProvider());
}