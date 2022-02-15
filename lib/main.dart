import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:custom_timer/custom_timer.dart';
// import 'package:path/path.dart' as p;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dotted_decoration/dotted_decoration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:filesize/filesize.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'package:stream_broadcast_sos/providers/firebase.dart';
import 'package:stream_broadcast_sos/providers/location.dart';
import 'package:stream_broadcast_sos/services/notification.dart';
import 'package:stream_broadcast_sos/utils/global.dart';
import 'package:stream_broadcast_sos/providers.dart';
import 'package:stream_broadcast_sos/providers/network.dart';
import 'package:stream_broadcast_sos/providers/videos.dart';
import 'package:stream_broadcast_sos/services/socket.dart';
import 'package:stream_broadcast_sos/basewidgets/button/custom.dart';
import 'package:stream_broadcast_sos/container.dart' as core;
import 'package:stream_broadcast_sos/services/video.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await core.init();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        title: 'SOS Broadcast Video',
        navigatorKey: GlobalVariable.navState,
        debugShowCheckedModeBanner: false,
        home: MyHomePage(key: UniqueKey()),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver, TickerProviderStateMixin {
  late Subscription? subscription;
  late TextEditingController msgController;
  late FirebaseProvider firebaseProvider;
  late LocationProvider locationProvider;
  late NetworkProvider networkProvider;
  late VideoProvider videoProvider;

  final double _minAvailableZoom = 1.0;
  final double _maxAvailableZoom = 1.0;
  final CustomTimerController customTimercontroller = CustomTimerController();

  Timer? timer;

  dynamic currentBackPressTime;
  bool isLoading = false;
  bool isCompressed = false;
  Uint8List? thumbnail;
  File? file;
  File? fx;
  MediaInfo? videoCompressInfo;
  Duration? duration;
  double? progress;
  int? videoSize;
  CameraController? controller;
  XFile? videoFile;
  VideoPlayerController? videoController;

  double _baseScale = 1.0;
  double _currentScale = 1.0;

  int _pointers = 0;

  Future<void> onInitCamera() async {
    if (controller != null) {
      await controller!.dispose();
    }

    CameraController cameraController = CameraController(
      const CameraDescription(
        name: "0", 
        lensDirection: CameraLensDirection.back, 
        sensorOrientation: 90,
      ),
      kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        showInSnackBar('Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  Future<void> onVideoRecordButtonPressed() async {
    startVideoRecording().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<XFile?> onStopButtonPressed(BuildContext ctx) async {
    XFile? xfile = await stopVideoRecording();
    if (xfile != null) {
      Navigator.of(context).pop();
      File f = File(xfile.path);
      if(mounted) {
        setState(() {
          isCompressed = true;
          file = File(f.path);
        });
      }
      await generateThumbnail(file!);
      await getVideoSize(file!);
      await GallerySaver.saveVideo(file!.path);
      final info = await VideoServices.compressVideo(file!);
      debugPrint(info!.path.toString());
      if(mounted) {
        setState(() {
          isCompressed = false;
          videoCompressInfo = info;
          duration = Duration(microseconds: (videoCompressInfo!.duration! * 1000).toInt());
        });
      }
      File(file!.path).deleteSync();  
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      showInSnackBar('Error: select a camera first.');
      return;
    }

    if (cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.startVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (controller == null || _pointers != 2) {
      return;
    }
    _currentScale = (_baseScale * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
    await controller!.setZoomLevel(_currentScale);
  }

  Future<XFile?> stopVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      return cameraController.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  Future<void> generateThumbnail(File file) async {
    final thumbnailBytes = await VideoCompress.getByteThumbnail(file.path);
    setState(() {
      thumbnail = thumbnailBytes;
    });
  }

  Future<void> getVideoSize(File file) async {
    final size = await file.length(); 
    setState(() {
      videoSize = size;
    });
  }

  Widget _cameraPreviewWidget() {
    if (controller == null || !controller!.value.isInitialized) {
      return Container();
    } else {
      return Listener(
        onPointerDown: (_) => _pointers++,
        onPointerUp: (_) => _pointers--,
        child: CameraPreview(
          controller!,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onTapDown: (details) => onViewFinderTap(details, constraints),
            );
          }),
        ),
      );
    }
  }

  @override 
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      if(mounted) {
        videoProvider.fetchFcm(context);
      }
    });
  }
  
  @override 
  void initState() {
    super.initState();

    firebaseProvider = context.read<FirebaseProvider>();
    videoProvider = context.read<VideoProvider>();
    networkProvider = context.read<NetworkProvider>();
    locationProvider = context.read<LocationProvider>();

    NotificationService.init();
    
    (() async {
      PermissionStatus permissionStorage = await Permission.storage.status;
      if(!permissionStorage.isGranted) {
        await Permission.storage.request();
      } 
    });
    
    msgController = TextEditingController();
         
    subscription = VideoCompress.compressProgress$.subscribe((event) {
      setState(() {
        progress = event;
      }); 
    });
    
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      await onInitCamera();

      if(mounted) {
        networkProvider.checkConnection(context);
      }
      if(mounted) {
        locationProvider.getCurrentPosition(context);
      }
      if(mounted) {
        SocketServices.shared.connect(context);
      }
    });
  }

  @override 
  void dispose() {
    msgController.dispose();
    controller!.dispose();
    customTimercontroller.dispose();
    SocketServices.shared.dispose();
    VideoCompress.cancelCompression();
    subscription!.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressBar = progress == null ? 0 : (progress!).toInt(); 
    return WillPopScope(
      onWillPop: () {
        DateTime now = DateTime.now();
        if (currentBackPressTime == null || now.difference(currentBackPressTime) > const Duration(seconds: 2)) {
          currentBackPressTime = now;
          Fluttertoast.showToast(msg: "Tekan sekali lagi untuk keluar");
          return Future.value(false);
        }
        SystemNavigator.pop();
        return Future.value(true);
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF6F6F6),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Consumer<NetworkProvider>(
                builder: (BuildContext context, NetworkProvider networkProvider, Widget? child) {
                  if(networkProvider.connectionStatus == ConnectionStatus.offInternet) {
                    return const Center(
                      child: SpinKitThreeBounce(
                        size: 20.0,
                        color: Colors.black87,
                      ),
                    );
                  }
                  return RefreshIndicator(
                    backgroundColor: Colors.black,
                    color: Colors.white,
                    onRefresh: () {
                      return Future.sync(() {
                        SocketServices.shared.connect(context);
                      });
                    },
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [

                        SliverAppBar(
                          backgroundColor: Colors.white,
                          elevation: 0.0,
                          centerTitle: true,
                          title: const Text("SOS Broadcast Video",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16.0
                            ),
                          ),
                          bottom: PreferredSize(
                            child: Consumer<LocationProvider>(
                              builder: (BuildContext context, LocationProvider locationProvider, Widget? child) {
                                return Container(
                                  color: const Color(0xffF6F6F6),
                                  width: double.infinity,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(locationProvider.getCurrentNameAddress,
                                    style: const TextStyle(
                                      fontSize: 14.0
                                    ),
                                  ),
                                );
                              },
                            ), 
                            preferredSize: const Size.fromHeight(60.0) 
                          ),
                        ),
                    
                        SliverFillRemaining(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.all(18.0),
                                decoration: DottedDecoration(
                                  shape: Shape.box, 
                                  color: Colors.black87, 
                                  strokeWidth: 2
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                                        type: FileType.video,
                                      );
                                      File f = File(result!.files.single.path!);
                                      setState(() {
                                        isCompressed = true;
                                        file = File(f.path);
                                      });
                                      await generateThumbnail(file!);
                                      await getVideoSize(file!);
                                      final info = await VideoServices.compressVideo(file!);
                                      setState(() {
                                        isCompressed = false;
                                        videoCompressInfo = info;
                                        duration = Duration(microseconds: (videoCompressInfo!.duration! * 1000).toInt());
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(30.0),
                                      child: videoSize == null && thumbnail == null ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Expanded(
                                          //   child: Column(
                                          //     children: const [
                                          //       Icon(
                                          //         Icons.video_call,
                                          //         size: 20.0,
                                          //         color: Colors.black87,
                                          //       ),
                                          //       SizedBox(height: 5.0),
                                          //       Text("Browse a Video",
                                          //         style: TextStyle(
                                          //           fontSize: 16.0
                                          //         ),
                                          //       ),
                                          //     ],
                                          //   ),
                                          // ),
                                          Expanded(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () async {
                          
                                                  await onVideoRecordButtonPressed();

                                                  customTimercontroller.start();

                                                  timer = Timer.periodic(const Duration(seconds: 15), (timer) {
                                                    onStopButtonPressed(context);
                                                    timer.cancel();
                                                  });
                          
                                                  Navigator.push(context,
                                                    PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) {
                                                      return WillPopScope(
                                                        onWillPop: () {
                                                          timer!.cancel();
                                                          // customTimercontroller.reset();
                                                          return Future.value(true);
                                                        },
                                                        child: Scaffold(
                                                          key: UniqueKey(),
                                                          body: SafeArea(
                                                            child: Stack(
                                                              clipBehavior: Clip.none,
                                                              children: [
                                                                                                      
                                                                Container(
                                                                  padding: const EdgeInsets.all(1.0),
                                                                  width: double.infinity,
                                                                  height: double.infinity,
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.black,
                                                                    border: Border.all(
                                                                      color: controller != null && controller!.value.isRecordingVideo
                                                                      ? Colors.redAccent
                                                                      : Colors.grey,
                                                                      width: 3.0,
                                                                    ),
                                                                  ),
                                                                  child: _cameraPreviewWidget()
                                                                ),

                                                                Container(
                                                                  margin: const EdgeInsets.only(bottom: 150.0),
                                                                  child: Align(
                                                                    alignment: Alignment.center,
                                                                    child: CustomTimer(
                                                                      controller: customTimercontroller,
                                                                      begin: const Duration(seconds: 15),
                                                                      end: const Duration(),
                                                                      builder: (time) {
                                                                        return Text(
                                                                          time.seconds,
                                                                          style: const TextStyle(
                                                                            color: Colors.white,
                                                                            fontSize: 50.0
                                                                          )
                                                                        );
                                                                      },
                                                                      stateBuilder: (time, state) {
                                                                        if(state == CustomTimerState.paused) {
                                                                          const Text("The timer is paused",
                                                                            style: TextStyle(fontSize: 24.0)
                                                                          );
                                                                        }
                                                                        return null;
                                                                      },
                                                                      animationBuilder: (Widget child) {
                                                                        return AnimatedSwitcher(
                                                                          duration: const Duration(milliseconds: 250),
                                                                          child: child,
                                                                        );
                                                                      },
                                                                      onChangeState: (state) { }
                                                                    ),
                                                                  ),
                                                                ),
                                                                
                                                                Align(
                                                                  alignment: Alignment.center,
                                                                  child: Container(
                                                                    padding: const EdgeInsets.all(5.0),
                                                                    decoration: const BoxDecoration(
                                                                      color: Colors.white,
                                                                      shape: BoxShape.circle
                                                                    ),
                                                                    child: IconButton(
                                                                      icon: const Icon(Icons.stop),
                                                                      color: Colors.red,
                                                                      onPressed: controller != null &&
                                                                      controller!.value.isInitialized &&
                                                                      controller!.value.isRecordingVideo
                                                                      ? () => onStopButtonPressed(context)
                                                                      : null,
                                                                    ),
                                                                  ),
                                                                ),
                                                                                                      
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                      const begin = Offset(-1.0, 0.0);
                                                      const end = Offset.zero;
                                                      const curve = Curves.ease;
                                                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                                      return SlideTransition(
                                                        position: animation.drive(tween),
                                                        child: child,
                                                      );
                                                    })
                                                  );
                                                },
                                                child: Column(
                                                  children: const [
                                                    Icon(
                                                      Icons.videocam,
                                                      size: 20.0,
                                                      color: Colors.black87,
                                                    ),
                                                    SizedBox(height: 5.0),
                                                    Text("Record a Video",
                                                      style: TextStyle(
                                                        fontSize: 16.0
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          )
                                        ],
                                      ) : isCompressed 
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SpinKitThreeBounce(
                                              size: 20.0,
                                              color: Colors.black87,
                                            ),
                                            const SizedBox(height: 10.0),
                                            Text("${progressBar.toString()} %",
                                              style: const TextStyle(
                                                fontSize: 14.0
                                              ),
                                            )
                                          ]
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                          Image.memory(thumbnail!, height: 100.0),
                                          const SizedBox(height: 12.0),
                                          Text("Size : ${filesize(videoSize)}",
                                            style: const TextStyle(
                                              fontSize: 16.0
                                            ),
                                          ),
                                          const SizedBox(height: 12.0),
                                          Text("Duration : ${duration!.inHours}:${duration!.inMinutes.remainder(60)}:${(duration!.inSeconds.remainder(60))}",
                                            style: const TextStyle(
                                              fontSize: 16.0
                                            ),
                                          ),
                                          const  SizedBox(height: 12.0),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                videoSize = null;
                                                thumbnail = null;
                                                videoCompressInfo = null;
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              primary: Colors.redAccent[200]
                                            ),
                                            child: const Text("Batal",
                                              style: TextStyle(
                                                fontSize: 16.0
                                              ),
                                            )
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ) 
                              ),
                              
                              Container(
                                margin: const EdgeInsets.only(left: 16.0, right: 16.0),
                                child: TextField(
                                  controller: msgController,
                                  cursorColor: Colors.black87,
                                  style: const TextStyle(
                                    fontSize: 14.0,
                                    height: 1.5,
                                    color: Colors.black87
                                  ),
                                  obscureText: false,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    label: const Text("Message",
                                      style: TextStyle(
                                        fontSize: 15.0,
                                        color: Colors.black87
                                      ),
                                    ),
                                    floatingLabelBehavior: FloatingLabelBehavior.always,
                                    fillColor: Colors.white,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                                    border: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: Colors.black87
                                      ),
                                      borderRadius: BorderRadius.circular(6.0),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(
                                        color: Colors.black87
                                      ),
                                      borderRadius: BorderRadius.circular(6.0),
                                    )
                                  ),
                                ),
                              ),
                                              
                              Container(
                                margin: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0), 
                                child: CustomButton(
                                  btnTxt: "Submit",
                                  height: 40.0,
                                  isBorder: false,
                                  isBorderRadius: false,
                                  isBoxShadow: false,
                                  isLoading: isLoading ? true : false, 
                                  onTap: () async {
                                    if(msgController.text.trim().isEmpty) return;
                                    if(videoCompressInfo == null) return;
                                    if(context.read<LocationProvider>().getCurrentLat == 0.0) return;
                                    if(context.read<LocationProvider>().getCurrentLng == 0.0) return;
                                    // Reference ref = FirebaseStorage.instance.ref().child('${const Uuid().v4()}.mp4');
                                    // UploadTask task = ref.putFile(File(videoCompressInfo!.path!));
                                    setState(() {
                                      isLoading = true;
                                    });
                                    // String url = await task.then((result) async {
                                    //   return await result.ref.getDownloadURL();
                                    // });
                                    // String url = p.basename(videoCompressInfo!.path!);
                                    String? url = await context.read<VideoProvider>().uploadVideo(file: videoCompressInfo!.file!);
                                    SocketServices.shared.sendMsg(
                                      id: const Uuid().v4(),
                                      msg: msgController.text,
                                      mediaUrl: url!,
                                      lat: context.read<LocationProvider>().getCurrentLat,
                                      lng: context.read<LocationProvider>().getCurrentLng
                                    );
                                    context.read<FirebaseProvider>().sendNotification(context,
                                      title: "SOS", 
                                      body: msgController.text
                                    );
                                    msgController.text = "";
                                    setState(() {
                                      isLoading = false;
                                      videoCompressInfo = null;
                                      duration = null;
                                      videoSize = null;
                                      thumbnail = null;
                                    });
                                  },
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },   
              );
            },
          ),
        )
        
      ),
    );
  }
}
