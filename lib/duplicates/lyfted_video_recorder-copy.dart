import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/session_state.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class LyftedVideoRecorder extends StatefulWidget {
  @override
  _LyftedVideoRecorderState createState() => _LyftedVideoRecorderState();
}

class _LyftedVideoRecorderState extends State<LyftedVideoRecorder>
    with TickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _vidFilePath;
  String? _mainFilePath;
  Directory? directory;
  Directory? subdirectory;
  Directory? vidSubdirectory;
  bool _isRecording = false;
  bool _firstTime = false;
  bool _uploadingDone = true;
  bool _isPlaying = false;
  bool _isFinished = false;
  bool _isDeleted = false;
  int _elapsedSeconds = 0;
  int _questionIndex = 0;
  double _questionProgress = 1.0;
  StreamController<int>? _streamController;
  Timer? _timer;
  Timer? _questionTimer;
  int _questionDuration = 5;
  late AnimationController _animationController;
  List<String> questions = [
    'Are you in control of\nyour life?',
    'How was\nyour day?',
    'How do you feel\nwith your family?',
    'How was your\nwork today?',
    'How do you describe\nyour life balance?',
  ];
  final GlobalKey<_PieTimerState> _pieTimerKey = GlobalKey<_PieTimerState>();

  @override
  void initState() {
    // Get the list of available cameras
    availableCameras().then((cameras) async {
      // Get the front-facing camera (usually index 0)
      CameraDescription camera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras[0]);
      // Create a CameraController instance and initialize it
      _controller = CameraController(
        camera,
        ResolutionPreset.max,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _initializeControllerFuture = _controller?.initialize();
      await _initializeControllerFuture;
      _createDir();
      _streamController = StreamController<int>.broadcast();
      _streamController?.add(_elapsedSeconds);
      _animationController =
          new AnimationController(vsync: this, duration: Duration(seconds: 1));
      _animationController.repeat(reverse: true);
      setState(() {
        _firstTime = true;
      });
    });
    super.initState();
  }

  Future<void> _createDir() async {
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    subdirectory = Directory('${directory!.path}/my_video_files');
    vidSubdirectory = Directory('${directory!.path}/my_extracted_audio_files');
    if (subdirectory != null && vidSubdirectory != null) {
      await subdirectory?.create(recursive: true);
      await vidSubdirectory?.create(recursive: true);
    }
  }

  void _startTimer() {
    if (_timer == null) {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds += 1;
        });
        _streamController?.add(_elapsedSeconds);
      });
    }
  }

  void _stopTimer() {
    _streamController?.close();
    _streamController = StreamController<int>.broadcast();
    _resetTimer();
    _timer?.cancel();
    _timer = null;
    _questionTimer!.cancel();
  }

  void _resetTimer() {
    _elapsedSeconds = 0;
    _streamController?.add(_elapsedSeconds);
  }

  void _startQuestionTimer() {
    _questionTimer = Timer.periodic(Duration(milliseconds: 1000), (_) {
      setState(() {
        if (_questionDuration > 1) {
          _questionDuration--;
        } else {
          if (!(_questionIndex == questions.length - 1)) {
            _changeQuestion(true);
          }
        }
      });
    });
  }

  void resetPieTimer() async {
    if (_questionIndex == questions.length - 1) {
      setState(() {
        // _pieTimerKey.currentState?.reset();
        _pieTimerKey.currentState?.onFinalIndex();
      });
    } else {
      setState(() {
        _pieTimerKey.currentState?.reset();
      });
    }
  }

  void _resetQuestionTimer() {
    setState(() {
      _questionProgress = 1.0;
      _questionDuration = 5;
    });
  }

  void _changeQuestion(bool isForward) {
    if (isForward) {
      setState(() {
        _questionIndex++;
      });
    } else {
      setState(() {
        _questionIndex--;
      });
    }
    _questionTimer?.cancel();
    resetPieTimer();
    _resetQuestionTimer();
    _startQuestionTimer();
  }

  String generateRandomString(int len) {
    var r = Random();
    const _chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _startVideoRecording() async {
    var status = await Permission.camera.request();
    if (status == PermissionStatus.granted) {
      await _initializeControllerFuture;
      _elapsedSeconds = 0;

      setState(() {
        _isFinished = true;
        _isPlaying = false;
      });
      await _controller?.startVideoRecording();
      setState(() {
        _isRecording = true;
        _isDeleted = false;
        _firstTime = false;
        _questionIndex = 0;
      });
      _resetTimer();
      _startTimer();
      _startQuestionTimer();
    }
  }

  Future<void> _stopVideoRecording() async {
    _stopTimer();
    _resetQuestionTimer();
    setState(() {
      _isRecording = false;
    });
    final savedPath = await _controller?.stopVideoRecording();
    setState(() {
      _vidFilePath = savedPath!.path;
      _questionIndex = 0;
    });
  }

  Future<void> _extractAudio(String vidPath) async {
    String extractedDirPath = directory!.path + '/my_extracted_audio_files';
    String extractedFilePath = extractedDirPath + '/ext-audio.mp3';
    setState(() {
      _mainFilePath = extractedFilePath;
    });
    Completer<void> completer = Completer<void>();
    await FFmpegKit.executeAsync(
        "-y -i $vidPath -vn -acodec libmp3lame -q:a 4 $extractedFilePath",
        (session) async {
      if (await session.getState() == SessionState.completed) {
        completer.complete();
      }
    }).then((result) {}).catchError((error) {
      completer.completeError(error);
    });
    await completer.future;
  }

  Future<void> _deleteAudio() async {
    setState(() {
      _isDeleted = true;
      _firstTime = true;
    });
  }

  Future<void> _uploadAudio(Uint8List audioFile) async {
    if (await File(_mainFilePath!).exists()) {
      setState(() {
        _uploadingDone = false;
      });
      String randomAudioID = generateRandomString(8);
      String fileName = 'audio-$randomAudioID.mp3';
      SettableMetadata fileMetaData =
          SettableMetadata(contentType: 'audio/mpeg');
      Reference firebaseStorageRef =
          FirebaseStorage.instance.ref().child("audios/$fileName");
      UploadTask uploadTask =
          firebaseStorageRef.putData(audioFile, fileMetaData);
      TaskSnapshot? taskSnapshot;
      try {
        taskSnapshot = await uploadTask;
      } on FirebaseException catch (e) {
        print("FirebaseException: $e");
      }
      String downloadUrl = await taskSnapshot!.ref.getDownloadURL();
      print("downloadUrl: $downloadUrl");
      await File(_mainFilePath!).delete();
      setState(() {
        _isDeleted = true;
        _firstTime = true;
      });
    }
  }

  Future<void> _confirmAudio() async {
    setState(() {
      _uploadingDone = false;
    });
    await _extractAudio(_vidFilePath!);
    await _uploadAudio(await File(_mainFilePath!).readAsBytes());
    setState(() {
      _questionIndex = 0;
      _uploadingDone = true;
    });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      // Show a loading spinner while the camera is loading
      return Center(child: CircularProgressIndicator());
    }
    final size = MediaQuery.of(context).size;
    // calculate scale for aspect ratio widget
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Material(
      child: Stack(
        children: [
          Transform.scale(
            scale: scale,
            child: Center(child: CameraPreview(_controller!)),
          ),
          Align(
            alignment: AlignmentDirectional(0, 1),
            child: Container(
              height: MediaQuery.of(context).size.height / 1.85,
              width: MediaQuery.of(context).size.width,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.ibmPlexSerif(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w400),
                                children: <TextSpan>[
                                  TextSpan(text: questions[_questionIndex]),
                                ],
                              ),
                            ),
                            Container(
                              width: MediaQuery.of(context).size.width / 1.75,
                              margin: EdgeInsets.only(top: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildBlur(
                                    borderRadius: BorderRadius.circular(20),
                                    child: _questionIndex == 0
                                        ? SizedBox(width: 40)
                                        : InkWell(
                                            hoverColor: Colors.transparent,
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () {
                                              if (_questionIndex >= 0) {
                                                _changeQuestion(false);
                                              }
                                            },
                                            child: Container(
                                              height: 40,
                                              width: 40,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0x40FFFFFF)),
                                              child: Icon(
                                                Icons.arrow_back,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                  ),
                                  buildBlur(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: 85,
                                      height: 40,
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Color(0x40FFFFFF),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text('${_questionIndex + 1}/5',
                                              style: GoogleFonts.ibmPlexSerif(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w400)),
                                          Container(
                                            width: 20,
                                            height: 20,
                                            padding: EdgeInsets.all(1.5),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1,
                                              ),
                                            ),
                                            child: PieTimer(
                                                progress: _questionProgress,
                                                isVideoRecording: _isRecording,
                                                questionIndex: _questionIndex,
                                                key: _pieTimerKey,
                                                duration: Duration(
                                                    seconds:
                                                        _questionDuration)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  buildBlur(
                                    borderRadius: BorderRadius.circular(20),
                                    child: _firstTime ||
                                            _isDeleted ||
                                            !_isRecording ||
                                            _questionIndex ==
                                                questions.length - 1
                                        ? SizedBox(width: 40)
                                        : InkWell(
                                            hoverColor: Colors.transparent,
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () {
                                              if (_questionIndex <
                                                  questions.length - 1) {
                                                _changeQuestion(true);
                                              }
                                            },
                                            child: Container(
                                              height: 40,
                                              width: 40,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Color(0x40FFFFFF)),
                                              child: Icon(
                                                Icons.arrow_forward,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            )
                          ]),
                    ),
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height / 3.5,
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _firstTime || _isDeleted
                            ? Container(
                                height: 32, margin: EdgeInsets.only(bottom: 15))
                            : Container(
                                width: _isRecording ? 140 : 160,
                                height: 32,
                                margin: EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Color(0xFFE3EBEF),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10, 0, 10, 0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _isRecording
                                          ? FadeTransition(
                                              opacity: _animationController,
                                              child: FaIcon(
                                                FontAwesomeIcons.solidCircle,
                                                color: Color(0xFF953434),
                                                size: 14,
                                              ),
                                            )
                                          : _firstTime
                                              ? FaIcon(
                                                  FontAwesomeIcons.solidCircle,
                                                  color: Color(0xFF953434),
                                                  size: 14,
                                                )
                                              : FaIcon(
                                                  FontAwesomeIcons.pause,
                                                  color: Color(0xFF953434),
                                                  size: 14,
                                                ),
                                      Text(
                                        _isRecording || _firstTime
                                            ? 'REC'
                                            : 'Paused',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 14,
                                            color: Color(0xFF953434)),
                                      ),
                                      StreamBuilder<int>(
                                        stream: _streamController?.stream ??
                                            Stream.empty(),
                                        initialData: _elapsedSeconds,
                                        builder: (context, snapshot) {
                                          Duration duration = Duration(
                                              seconds: snapshot.data ?? 0);
                                          return Text(
                                            _formatDuration(duration) + " Min",
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF264045)),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.7,
                          child: Align(
                            alignment: AlignmentDirectional(0, 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Align(
                                  alignment: AlignmentDirectional(0, 0),
                                  child: _firstTime ||
                                          _isRecording ||
                                          _isDeleted
                                      ? null
                                      : InkWell(
                                          onTap: _deleteAudio,
                                          hoverColor: Colors.transparent,
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          child: Align(
                                            alignment:
                                                AlignmentDirectional(0, 0),
                                            child: Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Color(0xFFE3EBEF),
                                                    width: 1,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Color.fromRGBO(
                                                            0, 0, 0, 0.15),
                                                        blurRadius: 6.0,
                                                        offset: Offset(0, 2))
                                                  ]),
                                              child: Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFF953434),
                                                size: 25,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                                Align(
                                  alignment: AlignmentDirectional(0, 0),
                                  child: InkWell(
                                    onTap: _isRecording
                                        ? _stopVideoRecording
                                        : _startVideoRecording,
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    child: Container(
                                      width: 125,
                                      height: 125,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white),
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Color(0xFFE3EBEF),
                                            width: 1,
                                          ),
                                        ),
                                        child: Align(
                                          alignment: AlignmentDirectional(0, 0),
                                          child: Container(
                                            width: 100,
                                            height: 100,
                                            decoration: BoxDecoration(
                                                color: _isRecording
                                                    ? Colors.white
                                                    : Color(0xFF953434),
                                                shape: BoxShape.circle),
                                            child: Icon(
                                              _isRecording ? Icons.stop : null,
                                              color: _isRecording
                                                  ? Colors.black
                                                  : Colors.transparent,
                                              size: _isRecording ? 50 : 35,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: AlignmentDirectional(0, 0),
                                  child: _firstTime || _isRecording
                                      ? null
                                      : InkWell(
                                          onTap: _confirmAudio,
                                          hoverColor: Colors.transparent,
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          child: Align(
                                            alignment:
                                                AlignmentDirectional(0, 0),
                                            child: Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Color(0xFFE3EBEF),
                                                    width: 1,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Color.fromRGBO(
                                                            0, 0, 0, 0.15),
                                                        blurRadius: 6.0,
                                                        offset: Offset(0, 2))
                                                  ]),
                                              child: Icon(
                                                Icons.check,
                                                color: Color(0xFF487373),
                                                size: 25,
                                              ),
                                            ),
                                          ),
                                        ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_uploadingDone)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildBlur({
    required Widget child,
    required BorderRadius borderRadius,
    double sigmaX = 5,
    double sigmaY = 5,
  }) =>
      Container(
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
            child: child,
          ),
        ),
        decoration: BoxDecoration(boxShadow: [
          BoxShadow(
            blurRadius: 4,
            color: Color(0x3F000000),
            offset: Offset(0, 1),
          )
        ], borderRadius: BorderRadius.circular(20)),
      );
}

// class PieTimer extends StatefulWidget {
//   final double progress;
//   final Duration duration;
//   final bool isVideoRecording;
//   final int questionIndex;

//   PieTimer(
//       {required this.progress,
//       required this.duration,
//       required this.questionIndex,
//       required this.isVideoRecording});

//   @override
//   _PieTimerState createState() => _PieTimerState();
// }

// class _PieTimerState extends State<PieTimer>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Tween<double> _tween;

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       vsync: this,
//       duration: Duration(seconds: 5),
//     );
//     _tween = Tween<double>(begin: widget.progress, end: 0.0);
//     _animationController.addStatusListener((status) {
//       if (status == AnimationStatus.completed) {
//         _animationController.reset();
//         _animationController.forward();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//         width: 20,
//         height: 20,
//         child: widget.isVideoRecording
//             ? AnimatedBuilder(
//                 animation: _animationController,
//                 builder: (BuildContext context, Widget? child) {
//                   return CustomPaint(
//                     painter: _PieTimerPainter(
//                       progress: _tween.evaluate(
//                         AlwaysStoppedAnimation(
//                           _animationController.value,
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               )
//             : CustomPaint(
//                 painter: _PieTimerPainter(
//                     progress: widget
//                         .progress), // or any other widget that you want to render when not recording
//               ));
//   }

//   @override
//   void didUpdateWidget(covariant PieTimer oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.isVideoRecording != oldWidget.isVideoRecording) {
//       if (widget.isVideoRecording) {
//         _animationController.forward();
//       } else {
//         _animationController.reset();
//       }
//     }
//   }
// }
class PieTimer extends StatefulWidget {
  final double progress;
  final Duration duration;
  final bool isVideoRecording;
  final int questionIndex;
  final GlobalKey<_PieTimerState>? key;

  PieTimer(
      {required this.progress,
      required this.duration,
      required this.questionIndex,
      required this.isVideoRecording,
      required this.key})
      : super(key: key);

  @override
  _PieTimerState createState() => _PieTimerState();
}

class _PieTimerState extends State<PieTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Tween<double> _tween;

  // void onFinalIndex() async {
  //   _animationController.addStatusListener((status) {
  //     if (status == AnimationStatus.completed) {
  //       if (_animationController.isAnimating) {
  //         _animationController.stop();
  //       } else {
  //         _animationController
  //             .forward()
  //             .then((_) => _animationController.stop());
  //       }
  //     }
  //   });
  // }

  void onFinalIndex() async {
    _animationController.reset();
    _animationController.forward();
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_animationController.isAnimating) {
          _animationController.stop();
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _tween = Tween<double>(begin: widget.progress, end: 0.0);
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PieTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVideoRecording != oldWidget.isVideoRecording) {
      if (widget.isVideoRecording) {
        _animationController.forward();
      } else {
        _animationController.reset();
      }
    }
  }

  // Add this function to reset the animation controller
  void reset() {
    setState(() {
      _tween = Tween<double>(begin: widget.progress, end: 0.0);
      _animationController.reset();
      _animationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      child: widget.isVideoRecording
          ? AnimatedBuilder(
              animation: _animationController,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _PieTimerPainter(
                    progress: _tween.evaluate(
                      AlwaysStoppedAnimation(
                        _animationController.value,
                      ),
                    ),
                  ),
                );
              },
            )
          : CustomPaint(
              painter: _PieTimerPainter(progress: widget.progress),
            ),
    );
  }
}

class _PieTimerPainter extends CustomPainter {
  final double progress;

  _PieTimerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Draw the background circle
    final backgroundPaint = Paint()..color = Colors.transparent;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw the progress arc
    final progressPaint = Paint()..color = Colors.white;
    final startAngle = -pi / 2;
    final sweepAngle = progress * 2 * -pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, true, progressPaint);
  }

  @override
  bool shouldRepaint(_PieTimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
