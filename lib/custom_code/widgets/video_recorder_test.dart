// Automatic FlutterFlow imports
import 'package:ffmpeg_kit_flutter/ffprobe_session.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart'; // Imports custom functions
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';

class VideoRecorderTest extends StatefulWidget {
  const VideoRecorderTest({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  final double? width;
  final double? height;

  @override
  _VideoRecorderTestState createState() => _VideoRecorderTestState();
}

class _VideoRecorderTestState extends State<VideoRecorderTest> {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool _isRecording = false;
  late String _videoPath;

  @override
  void initState() {
    super.initState();
    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      if (cameras.length > 0) {
        _controller = CameraController(
          cameras[0],
          ResolutionPreset.high,
        );
        try {
          _controller.initialize().then((_) {
            if (!mounted) {
              return;
            }
            setState(() {});
          });
        } catch (e) {
          print(e);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startRecording() async {
    if (!_controller.value.isInitialized) {
      return;
    }

    final directory = await getExternalStorageDirectory();
    final subdirectory = Directory('${directory!.path}/my_video_files');
    await subdirectory.create(recursive: true);

    final DateTime now = DateTime.now();
    final String formattedDateTime =
        '${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}-${now.second}';

    final String filePath = '${subdirectory.path}/$formattedDateTime.mp4';

    try {
      await _controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _videoPath = filePath;
      });
    } catch (e) {
      print(e);
    }
  }

  void _stopRecording() async {
    if (!_controller.value.isRecordingVideo) {
      return;
    }

    try {
      final stoppedRecord = await _controller.stopVideoRecording();
      print("This is stoppedRecord ${stoppedRecord.saveTo(_videoPath)}");
      setState(() {
        _isRecording = false;
      });
      print('Video recorded to $_videoPath');
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(child: CameraPreview(_controller), width: 150, height: 150),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: EdgeInsets.all(16),
            child: FloatingActionButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: _isRecording ? Icon(Icons.stop) : Icon(Icons.videocam),
            ),
          ),
        ),
      ],
    );
  }
}
