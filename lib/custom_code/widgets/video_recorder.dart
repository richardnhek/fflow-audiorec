import 'dart:io';

import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit_config.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

class VideoRecorder extends StatefulWidget {
  @override
  _VideoRecorderState createState() => _VideoRecorderState();
}

class _VideoRecorderState extends State<VideoRecorder> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _filePath;
  Directory? directory;
  Directory? subdirectory;
  Directory? vidSubdirectory;
  final FFmpegKit _flutterFFmpeg = FFmpegKit();

  @override
  void initState() {
    super.initState();
    _createDir();
    // Get the list of available cameras
    availableCameras().then((cameras) async {
      // Get the front-facing camera (usually index 0)
      CameraDescription camera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras[0]);
      // Create a CameraController instance and initialize it
      _controller = CameraController(camera, ResolutionPreset.medium);
      _initializeControllerFuture = _controller?.initialize();
      await _initializeControllerFuture;
      // Start the camera preview
      setState(() {});
    });
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

  Future<void> _extractAudio(String vidPath) async {
    String extractedDirPath = directory!.path + '/my_extracted_audio_files';
    String currentDateTime = DateTime.now().toString();
    String extractedFilePath = extractedDirPath + '/ext-audio-56.mp3';
    FFmpegKitConfig.enableLogCallback((logCallback) {
      print("FFmpegKitConfig Log" + logCallback.getMessage());
    });
    final String command = '-i $vidPath -vn -acodec copy $extractedFilePath';
    final List<String> commandList = [
      '-i',
      vidPath,
      '-vn',
      '-acodec',
      'copy',
      extractedFilePath
    ];

    FFmpegKitConfig.selectDocumentForWrite(vidPath, "video/*").then((uri) {
      FFmpegKitConfig.getSafParameterForWrite(uri!).then((safUrl) {
        FFmpegKit.executeAsync(
            "-i $vidPath -vn -acodec libmp3lame -q:a 4 $extractedFilePath");
      });
    });

    // FFmpegKit.executeAsync(command, (session) async {
    //   if (ReturnCode.isSuccess(await session.getReturnCode())) {
    //     print('Audio extracted successfully!');
    //   } else {
    //     print('Failed to extract audio: ${await session.getFailStackTrace()}');
    //   }
    // });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      // Show a loading spinner while the camera is loading
      return Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.camera_alt),
                  onPressed: () {
                    // Switch between the front and back cameras
                    _controller?.dispose();
                    _controller = _controller?.description.lensDirection ==
                            CameraLensDirection.front
                        ? CameraController(
                            _controller!.description,
                            ResolutionPreset.medium,
                            enableAudio: true,
                          )
                        : CameraController(
                            _controller!.description,
                            ResolutionPreset.medium,
                            enableAudio: true,
                            imageFormatGroup: ImageFormatGroup.yuv420,
                          );
                    _initializeControllerFuture = _controller?.initialize();
                    setState(() {});
                  },
                ),
                FloatingActionButton(
                  child: Icon(Icons.circle),
                  onPressed: () async {
                    // Start recording the video
                    await _initializeControllerFuture;
                    final path = join(
                      (await getTemporaryDirectory()).path,
                      '${DateTime.now()}.mp4',
                    );
                    await _controller?.startVideoRecording();
                  },
                ),
                IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: () async {
                    String path = directory!.path + '/my_video_files';
                    String currentDateTime = DateTime.now().toString();
                    // final vidFilePath =
                    //     path + '/vid-recording-$currentDateTime.mp4';
                    final vidFilePath = path + '/vid-recording-56.mp4';
                    // Stop recording the video
                    final videoFilePath =
                        await _controller?.stopVideoRecording();
                    videoFilePath?.saveTo(vidFilePath);
                    _extractAudio(vidFilePath);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
