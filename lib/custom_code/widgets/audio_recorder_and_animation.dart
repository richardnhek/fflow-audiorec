// Automatic FlutterFlow imports
// Imports other custom widgets

import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!
import 'dart:math';
import 'dart:typed_data';
import 'package:dotted_line/dotted_line.dart';
import 'package:ffmpeg_kit_flutter_audio/session_state.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit_config.dart';

class AudioRecorderAndAnimation extends StatefulWidget {
  const AudioRecorderAndAnimation({Key? key, this.width, this.height})
      : super(key: key);

  final double? width;
  final double? height;

  @override
  _AudioRecorderAndAnimationState createState() =>
      _AudioRecorderAndAnimationState();
}

class _AudioRecorderAndAnimationState extends State<AudioRecorderAndAnimation>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  Directory? directory;
  Directory? subdirectory;
  String? _mainFilePath;
  String? _iOSRecordedPath;
  String? _iOSTmpRecordedPath;
  bool _firstTime = false;
  bool _isDeleted = false;
  int _elapsedSeconds = 0;
  StreamController<int>? _streamController;
  Timer? _timer;
  bool _uploadingDone = true;
  bool _isPlaying = false;
  bool _isFinished = false;
  late AnimationController _animationController;
  PlayerController playerController = PlayerController();
  RecorderController _recorderController = RecorderController()
    ..androidEncoder = AndroidEncoder.aac
    ..androidOutputFormat = AndroidOutputFormat.mpeg4
    ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
    ..sampleRate = 44100
    ..bitRate = 48000;
  RecorderController _iOSrecorderController = RecorderController()
    ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
    ..sampleRate = 44100
    ..bitRate = 48000;

  @override
  void initState() {
    _init();
    _streamController = StreamController<int>.broadcast();
    _streamController?.add(_elapsedSeconds);
    _animationController =
        new AnimationController(vsync: this, duration: Duration(seconds: 1));
    _animationController.repeat(reverse: true);
    playerController.onCompletion.listen((event) {
      setState(() {
        _isPlaying = false;
        _isFinished = true;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _streamController?.close();
    _timer?.cancel();
    playerController.dispose();
    _recorderController.dispose();
    _iOSrecorderController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _createDir();
    if (Platform.isIOS) {
      await Permission.microphone.request();
      await Permission.storage.request();
      await Permission.photos.request();
    }
  }

  Future<void> _createDir() async {
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getTemporaryDirectory();
    }
    subdirectory = Directory('${directory!.path}/my_audio_files_wf');
    await subdirectory?.create(recursive: true);
    setState(() {
      _firstTime = true;
      if (Platform.isIOS) {
        _iOSRecordedPath = '${subdirectory?.path}/original-audio.mp3';
        _iOSTmpRecordedPath = '${subdirectory?.path}/original-audio.m4a';
      }
    });
    if (Platform.isIOS) {
      await File(_iOSRecordedPath!).create();
      await File(_iOSTmpRecordedPath!).create();
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
  }

  void _startRecording() async {
    if (Platform.isAndroid) {
      var status = await Permission.microphone.request();
      if (status == PermissionStatus.granted) {
        _elapsedSeconds = 0;
        await _recorderController.record();
        setState(() {
          _isRecording = true;
          _isDeleted = false;
          _firstTime = false;
        });
        _resetTimer();
        _startTimer();
      }
    } else {
      _elapsedSeconds = 0;
      await _iOSrecorderController.record(path: _iOSTmpRecordedPath);
      setState(() {
        _isRecording = true;
        _isDeleted = false;
        _firstTime = false;
      });
      _resetTimer();
      _startTimer();
    }
  }

  Future<void> _stopRecording() async {
    if (Platform.isAndroid) {
      final recordedPath = await _recorderController.stop();
      await playerController.preparePlayer(
        path: recordedPath!,
        shouldExtractWaveform: true,
        noOfSamples: 100,
        volume: 1.0,
      );
      _stopTimer();
      setState(() {
        _isRecording = false;
        _recorderController.refresh();
        _recorderController.reset();
        _firstTime = false;
      });
      await _m4aToMp3Conversion(recordedPath);
    } else {
      final iOSDefaultRecPath = await _iOSrecorderController.stop();
      await playerController.preparePlayer(
        path: iOSDefaultRecPath!,
        shouldExtractWaveform: true,
        noOfSamples: 100,
        volume: 1.0,
      );
      _stopTimer();
      setState(() {
        _isRecording = false;
        _recorderController.refresh();
        _recorderController.reset();
        _firstTime = false;
      });
      await _m4aToMp3Conversion(iOSDefaultRecPath!);
    }
  }

  void _resetTimer() {
    _elapsedSeconds = 0;
    _streamController?.add(_elapsedSeconds);
  }

  Future<void> _m4aToMp3Conversion(String audioPath) async {
    if (Platform.isAndroid) {
      String convertedFilePath = '${subdirectory?.path}/converted-audio.mp3';
      setState(() {
        _mainFilePath = convertedFilePath;
      });
      Completer<void> completer = Completer<void>();
      await FFmpegKit.executeAsync(
          "-y -i $audioPath -vn -c:a libmp3lame -qscale:a 0 $convertedFilePath",
          (session) async {
        FFmpegKitConfig.enableLogCallback(null);
        FFmpegKitConfig.enableStatisticsCallback(null);
        var state =
            FFmpegKitConfig.sessionStateToString(await session.getState());
        print("FFmpeg process state changed: $state");
        if (await session.getState() == SessionState.completed) {
          completer.complete();
        }
      }).then((result) {}).catchError((error) {
        completer.completeError(error);
      });
      await completer.future;
    } else {
      setState(() {
        _mainFilePath = _iOSRecordedPath;
      });
      Completer<void> completer = Completer<void>();
      await FFmpegKit.executeAsync(
          "-y -i $audioPath -vn -c:a libmp3lame -qscale:a 0 $_iOSRecordedPath",
          (session) async {
        FFmpegKitConfig.enableLogCallback(null);
        FFmpegKitConfig.enableStatisticsCallback(null);
        var state =
            FFmpegKitConfig.sessionStateToString(await session.getState());
        print("FFmpeg process state changed: $state");
        if (await session.getState() == SessionState.completed) {
          completer.complete();
        }
      }).then((result) {}).catchError((error) {
        completer.completeError(error);
      });
      await completer.future;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String generateRandomString(int len) {
    var r = Random();
    const _chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  Future<void> _uploadAudio(Uint8List audioFile) async {
    if (await File(_mainFilePath!).exists()) {
      setState(() {
        _uploadingDone = false;
      });
      String randomAudioID = generateRandomString(8);
      String fileName = 'audio-$randomAudioID.mp3';
      Reference firebaseStorageRef =
          FirebaseStorage.instance.ref().child("audios/$fileName");
      UploadTask uploadTask = firebaseStorageRef.putData(audioFile);
      TaskSnapshot? taskSnapshot;
      try {
        taskSnapshot = await uploadTask;
      } on FirebaseException catch (e) {
        print("FirebaseException: $e");
      }
      String downloadUrl = await taskSnapshot!.ref.getDownloadURL();
      print("downloadUrl: $downloadUrl");
      await File(_mainFilePath!).delete();
      await _deleteAudio();
      setState(() {
        _uploadingDone = true;
      });
    }
  }

  Future<void> _deleteAudio() async {
    setState(() {
      _isDeleted = true;
      _firstTime = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Stack(children: [
        Align(
          alignment: AlignmentDirectional(0, 0),
          child: Container(
            height: MediaQuery.of(context).size.height / 2.25,
            width: MediaQuery.of(context).size.width,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment(0, -1),
                  child: Container(
                    height: MediaQuery.of(context).size.height / 6.75,
                    child: Column(
                      mainAxisAlignment: _firstTime || _isRecording
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.spaceAround,
                      children: [
                        _firstTime || _isDeleted
                            ? SizedBox()
                            : Container(
                                width: 160,
                                height: 32,
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
                        _firstTime || _isRecording
                            ? SizedBox(height: 0, width: 0)
                            : Container(
                                width: MediaQuery.of(context).size.width,
                                margin: EdgeInsets.symmetric(horizontal: 20),
                                padding: EdgeInsets.only(right: 20),
                                height: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: Color(0xFFE9F0F3),
                                    borderRadius: BorderRadius.circular(15)),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    AudioFileWaveforms(
                                        size: Size(
                                            MediaQuery.of(context).size.width /
                                                2,
                                            50),
                                        waveformType: WaveformType.long,
                                        playerController: playerController,
                                        playerWaveStyle: PlayerWaveStyle(
                                          fixedWaveColor: Color(0xFFA4BCCC),
                                          liveWaveColor: Color(0xFFA4BCCC),
                                          showSeekLine: false,
                                          backgroundColor: Colors.transparent,
                                          waveCap: StrokeCap.square,
                                          spacing: 5.0,
                                          showBottom: true,
                                        )),
                                    // Text(
                                    //   "${playerController.getDuration()} Min",
                                    //   style: GoogleFonts.inter(
                                    //       fontWeight: FontWeight.w600,
                                    //       fontSize: 14,
                                    //       color: Color(0xFF264045)),
                                    // ),
                                    FutureBuilder<String>(
                                      future: playerController
                                          .getDuration()
                                          .then((value) => _formatDuration(
                                              Duration(milliseconds: value))),
                                      builder: (context, snapshot) {
                                        return Text(
                                          "${snapshot.data} Min",
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Color(0xFF264045),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        if (_isPlaying) {
                                          await playerController.pausePlayer();
                                        } else {
                                          await playerController.startPlayer(
                                              finishMode: FinishMode.pause);
                                        }
                                        setState(() {
                                          _isPlaying = !_isPlaying;
                                        });
                                      },
                                      icon: FaIcon(
                                        _isPlaying
                                            ? FontAwesomeIcons.pause
                                            : (_isFinished
                                                ? FontAwesomeIcons.play
                                                : FontAwesomeIcons.play),
                                        color: Color(0xFF3E5C71),
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(-1, 0),
                  child: Transform.scale(
                    scaleX: -1.0,
                    child: _isRecording
                        ? Container(
                            height: 100,
                            child: AudioWaveforms(
                              size: Size(
                                  MediaQuery.of(context).size.width / 2, 100.0),
                              recorderController: Platform.isAndroid
                                  ? _recorderController
                                  : _iOSrecorderController,
                              waveStyle: WaveStyle(
                                waveColor: Color(0xFF183136),
                                waveCap: StrokeCap.square,
                                showDurationLabel: false,
                                spacing: 5.0,
                                showBottom: true,
                                extendWaveform: true,
                                showMiddleLine: false,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                Align(
                    alignment: AlignmentDirectional(1, 0),
                    child: _isRecording
                        ? Container(
                            alignment: Alignment.center,
                            height: 100,
                            width: MediaQuery.of(context).size.width / 2,
                            child: DottedLine(
                              direction: Axis.horizontal,
                              lineLength: MediaQuery.of(context).size.width / 2,
                              lineThickness: 2.0,
                              dashLength: 2.0,
                              dashColor: Colors.black,
                              dashRadius: 10.0,
                              dashGapLength: 5.0,
                              dashGapColor: Colors.transparent,
                            ),
                          )
                        : null),
                Align(
                  alignment: AlignmentDirectional(0, 0),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    height: MediaQuery.of(context).size.height / 6.75,
                    child: Align(
                      alignment: AlignmentDirectional(0, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Align(
                            alignment: AlignmentDirectional(0, 0),
                            child: _firstTime || _isRecording
                                ? null
                                : InkWell(
                                    onTap: _deleteAudio,
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                              color: Color.fromRGBO(
                                                  0, 0, 0, 0.15)),
                                          BoxShadow(
                                              color: Colors.white,
                                              blurRadius: 8.0,
                                              offset: Offset(0, 4)),
                                        ],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Color(0xFFE3EBEF),
                                          width: 1,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: AlignmentDirectional(0, 0),
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
                          ),
                          Align(
                            alignment: AlignmentDirectional(0, 0),
                            child: InkWell(
                              onTap: _isRecording
                                  ? _stopRecording
                                  : _startRecording,
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
                                    boxShadow: [
                                      BoxShadow(
                                          color: Color.fromRGBO(0, 0, 0, 0.15)),
                                      BoxShadow(
                                          color: Colors.white,
                                          blurRadius: 8.0,
                                          offset: Offset(0, 4)),
                                    ],
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
                                        _isRecording
                                            ? Icons.stop
                                            : Icons.mic_none,
                                        color: _isRecording
                                            ? Colors.black
                                            : Colors.white,
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
                                    onTap: () async {
                                      _uploadAudio(await File(_mainFilePath!)
                                          .readAsBytes());
                                    },
                                    hoverColor: Colors.transparent,
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(
                                              color: Color.fromRGBO(
                                                  0, 0, 0, 0.15)),
                                          BoxShadow(
                                              color: Colors.white,
                                              blurRadius: 8.0,
                                              offset: Offset(0, 4)),
                                        ],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Color(0xFFE3EBEF),
                                          width: 1,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: AlignmentDirectional(0, 0),
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
                                  ),
                          ),
                        ],
                      ),
                    ),
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
          )
      ]),
    );
  }
}
