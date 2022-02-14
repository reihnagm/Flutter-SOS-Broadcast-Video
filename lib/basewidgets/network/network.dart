// import 'dart:async';

// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:lottie/lottie.dart';
// import 'package:stream_broadcast_sos/services/socket.dart';

// enum ConnectionStatus { onInternet, offInternet}

// class NetworkWrapper extends StatefulWidget {
//   final Widget child;
//   const NetworkWrapper({ 
//     Key? key,
//     required this.child,
//   }) : super(key: key);

//   @override
//   _NetworkWrapperState createState() => _NetworkWrapperState();
// }

// class _NetworkWrapperState extends State<NetworkWrapper> {
//   StreamSubscription? connectedToInternet;

//   ConnectionStatus _connectionStatus = ConnectionStatus.offInternet;
//   ConnectionStatus get connectionStatus => _connectionStatus;

//   void setStateConnectionStatus(ConnectionStatus connectionStatus) {
//     setState(() {
//       _connectionStatus = connectionStatus;
//     });
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     connectedToInternet = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
//       if(result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
//         if(SocketServices.shared.socketStatus == SocketStatus.socketON) {
//           setStateConnectionStatus(ConnectionStatus.onInternet);
//           SocketServices.shared.connect(context);
//         }
//       } else {
//         if(SocketServices.shared.socketStatus == SocketStatus.socketOFF) {
//           setStateConnectionStatus(ConnectionStatus.offInternet);
//           SocketServices.shared.disconnect();
//         }
//       }
//     });
//   }

//   @override 
//   void dispose() {
//     connectedToInternet!.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return connectionStatus == ConnectionStatus.onInternet 
//     ? widget.child 
//     : Center(
//       child: LottieBuilder.asset("assets/lotties/no-internet.json",
//         height: 150.0
//       ),
//     );
//   }
// }