import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dotted_decoration/dotted_decoration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:filesize/filesize.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'package:stream_video/providers.dart';
import 'package:stream_video/providers/network.dart';
import 'package:stream_video/providers/videos.dart';
import 'package:stream_video/services/socket.dart';
import 'package:stream_video/basewidgets/button/custom.dart';
import 'package:stream_video/container.dart' as core;
import 'package:stream_video/services/video.dart';

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
  dynamic currentBackPressTime;
  late Subscription subscription;
  late TextEditingController msgController;
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
  XFile? imageFile;
  XFile? videoFile;
  VideoPlayerController? videoController;
  VoidCallback? videoPlayerListener;
  bool enableAudio = true;

  double _baseScale = 1.0;
  final double _minAvailableZoom = 1.0;
  final double _maxAvailableZoom = 1.0;
  double _currentScale = 1.0;

  int _pointers = 0;

  Future<void> _onInitCamera() async {
    if (controller != null) {
      await controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      const CameraDescription(
        name: "0", 
        lensDirection: CameraLensDirection.back, 
        sensorOrientation: 90
      ),
      kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
      enableAudio: enableAudio,
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
      await cameraController.startVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      kIsWeb ? ResolutionPreset.max : ResolutionPreset.medium,
      enableAudio: enableAudio,
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

  Future<void> pauseVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.pauseVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  Future<void> resumeVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.resumeVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      rethrow;
    }
  }

  void _showCameraException(CameraException e) {
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
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
  void initState() {
    super.initState();
    msgController = TextEditingController();
    if(mounted) {
      subscription = VideoCompress.compressProgress$.subscribe((event) {
        setState(() {
          progress = event;
        }); 
      });
    }
    if(mounted) {
      context.read<VideoProvider>().listenV(context);
    }
    if(mounted) {
      context.read<NetworkProvider>().checkConnection(context);
    }
    if(mounted) {
      SocketServices.shared.connect(context);
    }
    (() async {
      PermissionStatus status = await Permission.storage.status;
      if(!status.isGranted) {
        await Permission.storage.request();
      } 
    });
    _onInitCamera();
    _ambiguate(WidgetsBinding.instance)?.addObserver(this);
  }

  @override 
  void dispose() {
    _ambiguate(WidgetsBinding.instance)?.removeObserver(this);
    msgController.dispose();
    subscription.unsubscribe();
    VideoCompress.cancelCompression();
    SocketServices.shared.dispose();
    super.dispose();
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.0,
          centerTitle: true,
          title: const Text("SOS Broadcast Video",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16.0
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Consumer<NetworkProvider>(
                builder: (BuildContext context, NetworkProvider networkProvider, Widget? child) {
                  if(networkProvider.connectionStatus == ConnectionStatus.offInternet) {
                    return const Center(
                      child: Text("There is no Connection / Socket is off",
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold
                        ),
                      )
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
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 25.0, bottom: 25.0),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                        
                                    Container(
                                      margin: const EdgeInsets.only(left: 16.0, right: 16.0, top: 80.0, bottom: 80.0),
                                      child: Consumer<VideoProvider>(
                                        builder: (BuildContext context, VideoProvider videoProvider, Widget? child) {
                                          if(videoProvider.listenVStatus == ListenVStatus.loading) {
                                            return const Center(
                                              child: SpinKitThreeBounce(
                                                size: 20.0,
                                                color: Colors.black87,
                                              ),
                                            );
                                          }
                                          if(videoProvider.v.isEmpty) {
                                            return const Text("There is no Videos",
                                              style: TextStyle(
                                                fontSize: 15.0,
                                              ),
                                            );
                                          }
                                          return ListView.builder(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            padding: EdgeInsets.zero,
                                            itemCount: videoProvider.v.length,
                                            itemBuilder: (BuildContext context, int i) {
                                              VideoPlayerController? vid = videoProvider.v[i]["video"];
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 5.0),
                                                child: Card(
                                                  child: Container(
                                                    padding: const EdgeInsets.all(10.0),
                                                    child: Column( 
                                                      children: [
                        
                                                        vid != null && vid.value.isInitialized
                                                        ? Container(
                                                            alignment: Alignment.topCenter, 
                                                            child: Stack(
                                                              children: [
                                                                AspectRatio(
                                                                  aspectRatio: vid.value.aspectRatio,
                                                                  child: VideoPlayer(vid),
                                                                ),
                                                                Positioned.fill(
                                                                  child: GestureDetector(
                                                                    behavior: HitTestBehavior.opaque,
                                                                    onTap: () => vid.value.isPlaying 
                                                                    ? vid.pause() 
                                                                    : vid.play(),
                                                                    child: Stack(
                                                                      children: [
                                                                        vid.value.isPlaying 
                                                                        ? Container() 
                                                                        : Container(
                                                                            alignment: Alignment.center,
                                                                            child: const Icon(
                                                                              Icons.play_arrow,
                                                                              color: Colors.white,
                                                                              size: 80
                                                                            ),
                                                                          ),
                                                                        Positioned(
                                                                          bottom: 0.0,
                                                                          left: 0.0,
                                                                          right: 0.0,
                                                                          child: VideoProgressIndicator(
                                                                            vid,
                                                                            allowScrubbing: true,
                                                                          )
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  )
                                                                )
                                                              ],
                                                            )
                                                          )
                                                        : const SizedBox(
                                                          height: 200,
                                                          child: SpinKitThreeBounce(
                                                            size: 20.0,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                        
                                                        Container(
                                                          margin: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                                                          child: Center(
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                    Expanded(
                                                                      flex: 4,
                                                                      child: Text(videoProvider.v[i]["msg"].toString(),
                                                                        style: const TextStyle(
                                                                          fontSize: 16.0,
                                                                          fontWeight: FontWeight.bold
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    Expanded(
                                                                      flex: 1,
                                                                      child: Material(
                                                                        color: Colors.transparent,
                                                                        child: InkWell(
                                                                          onTap: () {
                                                                            videoProvider.deleteV(
                                                                              context, 
                                                                              id: videoProvider.v[i]["id"].toString()
                                                                            );
                                                                          },
                                                                          child: const Padding(
                                                                            padding: EdgeInsets.all(8.0),
                                                                            child: Icon(
                                                                              Icons.remove_circle,
                                                                              color: Colors.redAccent,
                                                                              size: 30.0,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )
                                                              ],
                                                            ) 
                                                          ),
                                                        )
                        
                                                      ],  
                                                    )
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    
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
                                                Expanded(
                                                  child: Column(
                                                    children: const [
                                                      Icon(
                                                        Icons.video_call,
                                                        size: 20.0,
                                                        color: Colors.black87,
                                                      ),
                                                      SizedBox(height: 5.0),
                                                      Text("Browse a Video",
                                                        style: TextStyle(
                                                          fontSize: 16.0
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () {
                                                        Navigator.push(context,
                                                          PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) {
                                                            return Scaffold(
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
                                          prefixIcon: const Icon(
                                            Icons.message,
                                            size: 20.0,
                                            color: Colors.black87,
                                          ),
                                          label: const Text("Write a Message",
                                            style: TextStyle(
                                              fontSize: 15.0,
                                              color: Colors.black87
                                            ),
                                          ),
                                          floatingLabelBehavior: FloatingLabelBehavior.auto,
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
                                          // String newString = p.basename(videoCompressInfo!.path!).replaceAll(p.basename(videoCompressInfo!.path!), '1');
                                          Reference ref = FirebaseStorage.instance.ref().child('${const Uuid().v4()}.mp4');
                                          UploadTask task = ref.putFile(File(videoCompressInfo!.path!));
                                          setState(() {
                                            isLoading = true;
                                          });
                                          String url = await task.then((result) async {
                                            return await result.ref.getDownloadURL();
                                          });
                                          SocketServices.shared.sendMsg(
                                            id: const Uuid().v4(),
                                            msg: msgController.text,
                                            mediaUrl: url
                                          );
                                          msgController.text = "";
                                          setState(() {
                                            videoCompressInfo = null;
                                            duration = null;
                                            videoSize = null;
                                            thumbnail = null;
                                            isLoading = false;
                                          });
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ])
                          ),
                        )
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

T? _ambiguate<T>(T? value) => value;