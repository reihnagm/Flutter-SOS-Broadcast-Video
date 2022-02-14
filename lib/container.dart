import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_broadcast_sos/providers/location.dart';
import 'package:stream_broadcast_sos/providers/network.dart';
import 'package:stream_broadcast_sos/providers/videos.dart';

final getIt = GetIt.instance;

Future<void> init() async {
  getIt.registerFactory(() => NetworkProvider());
  getIt.registerFactory(() => VideoProvider());
  getIt.registerFactory(() => LocationProvider(sharedPreferences: getIt()));

  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton(() => sharedPreferences);
}