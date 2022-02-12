import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dotted_decoration/dotted_decoration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:filesize/filesize.dart';
import 'package:stream_video/providers.dart';
import 'package:stream_video/providers/network.dart';
import 'package:stream_video/providers/videos.dart';
import 'package:stream_video/services/socket.dart';

import 'package:stream_video/basewidgets/button/custom.dart';
import 'package:stream_video/container.dart' as core;
import 'package:stream_video/services/video.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

Future<void> main() async {
  await core.init();
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

class _MyHomePageState extends State<MyHomePage> {
  dynamic currentBackPressTime;
  late TextEditingController msgController;
  bool isCompressed = false;
  Uint8List? thumbnail;
  String? title;
  File? file;
  File? fx;
  MediaInfo? videoCompressInfo;
  Duration? duration;
  int? videoSize;
  
  @override 
  void initState() {
    super.initState();
    msgController = TextEditingController();
    context.read<VideoProvider>().listenV(context);
    context.read<NetworkProvider>().checkConnection(context);
    SocketServices.shared.connect(context);
  }

  @override 
  void dispose() {
    msgController.dispose();
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
                                              return Container(
                                                margin: const EdgeInsets.only(bottom: 5.0),
                                                child: Card(
                                                  child: Container(
                                                    padding: const EdgeInsets.all(10.0),
                                                    child: Column( 
                                                      children: [
                        
                                                        videoProvider.videoController != null && videoProvider.videoController!.value.isInitialized
                                                        ? Container(
                                                            alignment: Alignment.topCenter, 
                                                            child: Stack(
                                                              children: [
                                                                AspectRatio(
                                                                  aspectRatio: videoProvider.videoController!.value.aspectRatio,
                                                                  child: VideoPlayer(videoProvider.videoController!),
                                                                ),
                                                                Positioned.fill(
                                                                  child: GestureDetector(
                                                                    behavior: HitTestBehavior.opaque,
                                                                    onTap: () =>    videoProvider.videoController! .value.isPlaying 
                                                                    ? videoProvider.videoController!.pause() 
                                                                    : videoProvider.videoController!.play(),
                                                                    child: Stack(
                                                                      children: [
                                                                        videoProvider.videoController!.value.isPlaying 
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
                                                                            videoProvider.videoController!,
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
                                                          margin: const EdgeInsets.only(top: 12.0, bottom: 12.0),
                                                          child: Center(
                                                            child: Text(videoProvider.v[i]["msg"].toString(),
                                                              style: const TextStyle(
                                                                fontSize: 16.0,
                                                                fontWeight: FontWeight.bold
                                                              ),
                                                            ),
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
                                              title = videoCompressInfo!.title!;
                                              duration = Duration(microseconds: (videoCompressInfo!.duration! * 1000).toInt());
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(30.0),
                                            child: videoSize == null && thumbnail == null ? Column(
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
                                            ) : isCompressed 
                                            ? const SpinKitThreeBounce(
                                                size: 20.0,
                                                color: Colors.black87,
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
                                        onTap: () {
                                          if(msgController.text.trim().isEmpty) return;
                                          if(videoCompressInfo == null) return;
                                          debugPrint( videoCompressInfo!.file!.path);
                                          SocketServices.shared.sendMsg(msg: msgController.text, mediaUrl: videoCompressInfo!.path!);
                                          msgController.text = "";
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
