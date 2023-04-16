// Automatic FlutterFlow imports
import 'dart:io';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderAndPlayerTest extends StatefulWidget {
  const AudioRecorderAndPlayerTest({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  final double? width;
  final double? height;

  @override
  _AudioRecorderAndPlayerTestState createState() =>
      _AudioRecorderAndPlayerTestState();
}

class _AudioRecorderAndPlayerTestState
    extends State<AudioRecorderAndPlayerTest> {
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;
  int _recordDuration = 0;
  String? path = '';
  Timer? _timer;
  Timer? _ampTimer;
  String? _filePath;
  String? _mp3FilePath;
  final _audioRecorder = Record();
  final player = AudioPlayer();

  Amplitude? _amplitude;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
  }

  void dispose() {
    _timer?.cancel();
    _ampTimer?.cancel();
    _audioRecorder.dispose();
    player.stop();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start();

        bool isRecording = await _audioRecorder.isRecording();
        setState(() {
          _isRecording = isRecording;
          _recordDuration = 0;
        });

        _startTimer();
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  // Future<void> _stop() async {
  //   _timer?.cancel();
  //   _ampTimer?.cancel();

  //   // This is the path of the recorded file.
  //   path = await _audioRecorder.stop();

  //   setState(() => _isRecording = false);
  //   setState(() => _isPaused = true);

  //   final directory = await getExternalStorageDirectory();
  //   print("directory: $directory");
  //   final subdirectory = Directory('${directory!.path}/my_audio_files');
  //   print("subdirectory: $subdirectory");
  //   await subdirectory.create(recursive: true);
  //   print("Subdirectory created: ${await subdirectory.exists()}");

  //   final mp3FilePath = '${subdirectory.path}/recording.mp3';
  //   String m4aFilePath = path!;

  //   final String command =
  //       '-i $m4aFilePath -vn -ar 44100 -ac 2 -b:a 192k -f mp3 $mp3FilePath';
  //   final storagePermissionStatus = await Permission.storage.status;
  //   if (storagePermissionStatus.isGranted) {
  //     await _copyAndConvertAudioFile(command, m4aFilePath, mp3FilePath);
  //   } else {
  //     final storagePermissionResult = await Permission.storage.request();
  //     if (storagePermissionResult.isGranted) {
  //       await _copyAndConvertAudioFile(command, m4aFilePath, mp3FilePath);
  //     } else {
  //       // Handle the user's response to the permission request
  //       // e.g. show a dialog explaining why the permission is needed
  //     }
  //   }
  // }

  // Future<void> _copyAndConvertAudioFile(
  //   String command,
  //   String m4aFilePath,
  //   String mp3FilePath,
  // ) async {
  //   await FFmpegKit.executeAsync(command);

  //   final fileTest = File(mp3FilePath);
  //   if (await fileTest.exists()) {
  //     print("File exists");
  //   } else {
  //     print("File does not exist");
  //   }
  // }
  Future<void> _stop() async {
    _timer?.cancel();
    _ampTimer?.cancel();

    // This is the path of the recorded file.
    path = await _audioRecorder.stop();

    setState(() => _isRecording = false);
    setState(() => _isPaused = true);

    final directory = await getExternalStorageDirectory();
    print("directory: $directory");
    final subdirectory = Directory('${directory!.path}/my_audio_files');
    print("subdirectory: $subdirectory");
    await subdirectory.create(recursive: true);

    final mp3FilePath = '${subdirectory.path}/recording.mp3';
    String m4aFilePath = path!;

    final String command =
        '-i $m4aFilePath -vn -ar 44100 -ac 2 -b:a 192k -f mp3 $mp3FilePath';
    FFmpegKit.executeAsync(command).then((result) async {
      print(await result.getState());
      if (await File(mp3FilePath).exists()) {
        print("File created successfully");
      } else {
        print("Error creating file");
      }
    }).catchError((error) {
      print("Error while running FFmpeg: $error");
    });

    try {
      final file = File(m4aFilePath);
      final copyFile = await file.copy(mp3FilePath);
      print("File copied successfully: ${copyFile.path}");
    } catch (error, stackTrace) {
      print("Error while copying file: $error");
      print(stackTrace);
    }
  }

  Future<void> _play() async {
    await player.setReleaseMode(ReleaseMode.loop);
    kIsWeb
        ? await player.play(UrlSource(path!))
        : await player.play(DeviceFileSource(path!));

    setState(() => _isPaused = false);
    setState(() => _isPlaying = true);
  }

  Future<void> _pause() async {
    await player.pause();

    setState(() => _isPaused = true);
    setState(() => _isPlaying = false);
  }

  Widget _buildTimer() {
    final String minutes = _formatNumber(_recordDuration ~/ 60);
    final String seconds = _formatNumber(_recordDuration % 60);

    return Text(
      '$minutes : $seconds',
      style: FlutterFlowTheme.of(context).bodyText1,
    );
  }

  Widget _buildText() {
    if (_isRecording) {
      return _buildTimer();
    } else if (_isPaused) {
      return Text(
        'Tap to listen',
        style: FlutterFlowTheme.of(context).bodyText1,
      );
    } else if (_isPlaying) {
      return Text(
        'Tap to pause',
        style: FlutterFlowTheme.of(context).bodyText1,
      );
    } else {
      return Text(
        'Tap to record',
        style: FlutterFlowTheme.of(context).bodyText1,
      );
    }
  }

  Widget _buildSubHeader() {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0, 10, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildText(),
        ],
      ),
    );
  }

  Widget _buildRecorder() {
    if (_isRecording) {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(0, 10, 0, 0),
        child: InkWell(
          onTap: () async {
            _stop();
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(0x4DD9376E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.stop_rounded,
              color: FlutterFlowTheme.of(context).tertiaryColor,
              size: 45,
            ),
          ),
        ),
      );
    } else if (_isPaused) {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(0, 10, 0, 0),
        child: InkWell(
          onTap: () async {
            _play();
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).alternate,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: FlutterFlowTheme.of(context).secondaryBackground,
              size: 45,
            ),
          ),
        ),
      );
    } else if (_isPlaying) {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(0, 10, 0, 0),
        child: InkWell(
          onTap: () async {
            _pause();
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pause_rounded,
              color: FlutterFlowTheme.of(context).alternate,
              size: 45,
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(0, 10, 0, 0),
        child: InkWell(
          onTap: () async {
            _start();
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Color(0x4DD9376E),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic_none,
              color: FlutterFlowTheme.of(context).tertiaryColor,
              size: 45,
            ),
          ),
        ),
      );
    }
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0' + numberStr;
    }

    return numberStr;
  }

  void _startTimer() {
    _timer?.cancel();
    _ampTimer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });

    _ampTimer =
        Timer.periodic(const Duration(milliseconds: 200), (Timer t) async {
      _amplitude = await _audioRecorder.getAmplitude();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRecorder(),
              _buildSubHeader(),
            ],
          ),
        ],
      ),
    );
  }
}
