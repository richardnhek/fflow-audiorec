// Automatic FlutterFlow imports
// Imports other custom widgets
import 'dart:math';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_audio/session_state.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';
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

class _AudioRecorderAndAnimationState extends State<AudioRecorderAndAnimation> {
  bool _isRecording = false;
  Directory? directory;
  Directory? subdirectory;
  String? _mainFilePath;
  bool _firstTime = false;
  RecorderController _recorderController = RecorderController()
    ..androidEncoder = AndroidEncoder.aac
    ..androidOutputFormat = AndroidOutputFormat.mpeg4
    ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
    ..sampleRate = 44100
    ..bitRate = 48000;

  @override
  void initState() {
    _init();
    super.initState();
  }

  Future<void> _init() async {
    await _createDir();
  }

  Future<void> _createDir() async {
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    subdirectory = Directory('${directory!.path}/my_audio_files_wf');
    await subdirectory?.create(recursive: true);
    setState(() {
      _firstTime = true;
    });
  }

  void _startRecording() async {
    var status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      await _recorderController.record();
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _stopRecording() async {
    final recordedPath = await _recorderController.stop();
    setState(() {
      _isRecording = false;
      _recorderController.refresh();
      _recorderController.reset();
      _firstTime = false;
    });
    await _m4aToMp3Conversion(recordedPath!);
  }

  Future<void> _m4aToMp3Conversion(String audioPath) async {
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
    if (await File(convertedFilePath).exists()) {
      await _uploadAudio(await File(convertedFilePath).readAsBytes());
    }
  }

  String generateRandomString(int len) {
    var r = Random();
    const _chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return List.generate(len, (index) => _chars[r.nextInt(_chars.length)])
        .join();
  }

  Future<void> _uploadAudio(Uint8List audioFile) async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Align(
        alignment: AlignmentDirectional(0, 0),
        child: Container(
          height: MediaQuery.of(context).size.height / 3,
          width: MediaQuery.of(context).size.width,
          child: Stack(
            children: [
              Align(
                alignment: AlignmentDirectional(-1, -1),
                child: Transform.scale(
                  scaleX: -1.0,
                  child: _isRecording
                      ? AudioWaveforms(
                          size: Size(
                              MediaQuery.of(context).size.width / 3, 100.0),
                          recorderController: _recorderController,
                          waveStyle: WaveStyle(
                            waveColor: Color(0xFF183136),
                            waveCap: StrokeCap.square,
                            showDurationLabel: false,
                            spacing: 5.0,
                            showBottom: true,
                            extendWaveform: true,
                            showMiddleLine: false,
                          ),
                        )
                      : null,
                ),
              ),
              Align(
                alignment: AlignmentDirectional(0, -1),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: 120,
                  child: Align(
                    alignment: AlignmentDirectional(0, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: AlignmentDirectional(0, 0),
                          child: !_firstTime
                              ? InkWell(
                                  onTap: _isRecording
                                      ? _stopRecording
                                      : _startRecording,
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
                                            color:
                                                Color.fromRGBO(0, 0, 0, 0.15)),
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
                                )
                              : null,
                        ),
                        Align(
                          alignment: AlignmentDirectional(0, 0),
                          child: InkWell(
                            onTap:
                                _isRecording ? _stopRecording : _startRecording,
                            hoverColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            highlightColor: Colors.transparent,
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
                                            color:
                                                Color.fromRGBO(0, 0, 0, 0.15),
                                            blurRadius: 6.0,
                                            offset: Offset(0, 2))
                                      ]),
                                  child: Icon(
                                    _isRecording ? Icons.stop : Icons.mic_none,
                                    color: _isRecording
                                        ? Colors.black
                                        : Colors.white,
                                    size: 35,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(0, 0),
                          child: !_firstTime
                              ? InkWell(
                                  onTap: _isRecording
                                      ? _stopRecording
                                      : _startRecording,
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
                                            color:
                                                Color.fromRGBO(0, 0, 0, 0.15)),
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
                                )
                              : null,
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
    );
  }
}
// Align(
//   alignment: AlignmentDirectional(0, -1),
//   child: Container(
//     width: MediaQuery.of(context).size.width * 0.8,
//     height: 100,
//     decoration: BoxDecoration(
//       color: FlutterFlowTheme.of(context).secondaryBackground,
//     ),
//     child: Align(
//       alignment: AlignmentDirectional(0, 0),
//       child: Row(
//         mainAxisSize: MainAxisSize.max,
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Align(
//             alignment: AlignmentDirectional(0, 0),
//             child: Container(
//               width: 80,
//               height: 80,
//               child: custom_widgets.AudioRecorderMP3ButtonV1(
//                 width: 80,
//                 height: 80,
//               ),
//             ),
//           ),
//           Align(
//             alignment: AlignmentDirectional(0, -1),
//             child: Container(
//               width: 100,
//               height: 100,
//               child: custom_widgets.AudioRecorderMP3ButtonV1(
//                 width: 100,
//                 height: 100,
//               ),
//             ),
//           ),
//           Align(
//             alignment: AlignmentDirectional(0, 0),
//             child: Container(
//               width: 80,
//               height: 80,
//               child: custom_widgets.AudioRecorderMP3ButtonV1(
//                 width: 80,
//                 height: 80,
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//   ),
// )