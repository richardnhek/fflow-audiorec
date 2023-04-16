// Automatic FlutterFlow imports

import 'package:permission_handler/permission_handler.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:record_mp3/record_mp3.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';

class AudioRecorderFlutterSound extends StatefulWidget {
  const AudioRecorderFlutterSound({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  final double? width;
  final double? height;

  @override
  _AudioRecorderFlutterSoundState createState() =>
      _AudioRecorderFlutterSoundState();
}

class _AudioRecorderFlutterSoundState extends State<AudioRecorderFlutterSound> {
  bool _isRecording = false;
  String? _filePath;

  void _startRecording() async {
    Directory? directory = await getExternalStorageDirectory();
    String path = directory!.path + '/my_audio_files';
    String currentDateTime = DateTime.now().toString();

    if (!Directory(path).existsSync()) {
      Directory(path).createSync();
    }

    String filePath = path + '/recording-$currentDateTime.mp3';

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      // Permission was denied
      return;
    }

    RecordMp3.instance.start(filePath, (e) => {print(e)});

    setState(() {
      _isRecording = true;
      _filePath = filePath;
    });
  }

  void _stopRecording() async {
    RecordMp3.instance.stop();
    await uploadAudio(File(_filePath!));
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> uploadAudio(File audioFile) async {
    String fileName = basename(audioFile.path);
    Reference firebaseStorageRef =
        FirebaseStorage.instance.ref().child("audios/$fileName");
    UploadTask uploadTask = firebaseStorageRef.putFile(audioFile);
    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    print("downloadUrl: $downloadUrl");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Recorder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            if (_filePath != null) Text('Recording saved to: $_filePath'),
          ],
        ),
      ),
    );
  }
}
