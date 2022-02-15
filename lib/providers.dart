import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:stream_broadcast_sos/providers/firebase.dart';
import 'package:stream_broadcast_sos/providers/location.dart';
import 'package:stream_broadcast_sos/providers/network.dart';
import 'package:stream_broadcast_sos/providers/videos.dart';

import 'container.dart' as c;

List<SingleChildWidget> providers = [
  ...independentServices,
];

List<SingleChildWidget> independentServices = [
  ChangeNotifierProvider(create: (_) => c.getIt<NetworkProvider>()),
  ChangeNotifierProvider(create: (_) => c.getIt<VideoProvider>()),
  ChangeNotifierProvider(create: (_) => c.getIt<LocationProvider>()),
  ChangeNotifierProvider(create: (_) => c.getIt<FirebaseProvider>()),
  Provider.value(value: const <String, dynamic>{})
];