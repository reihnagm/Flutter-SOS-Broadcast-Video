import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStatus { onInternet, offInternet}

class NetworkProvider with ChangeNotifier {
  final SharedPreferences sharedPreferences;
  NetworkProvider({
    required this.sharedPreferences
  });

  StreamSubscription? connectedToInternet;

  bool isStillTurnOffSocket = false;

  ConnectionStatus _connectionStatus = ConnectionStatus.offInternet;
  ConnectionStatus get connectionStatus => _connectionStatus;

  void setStateConnectionStatus(ConnectionStatus connectionStatus) {
    _connectionStatus = connectionStatus;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  @override
  void dispose() {
    connectedToInternet!.cancel();
    super.dispose();  
  }

  void checkConnection(BuildContext context) {
    connectedToInternet = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if(isStillTurnOffSocket) {
         setStateConnectionStatus(ConnectionStatus.offInternet);
      } else {
          if(result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
          setStateConnectionStatus(ConnectionStatus.onInternet);
        } else {
          setStateConnectionStatus(ConnectionStatus.offInternet);
        }
      }
    });
  }

  void turnOnSocket() {
    setStateConnectionStatus(ConnectionStatus.onInternet);
    isStillTurnOffSocket = false;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  void turnOffSocket() {
    setStateConnectionStatus(ConnectionStatus.offInternet);
    isStillTurnOffSocket = true;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

}