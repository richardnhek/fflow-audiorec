import '/flutter_flow/flutter_flow_audio_player.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'audio_player_test_model.dart';
export 'audio_player_test_model.dart';
import 'package:path_provider/path_provider.dart';

class AudioPlayerTestWidget extends StatefulWidget {
  const AudioPlayerTestWidget({Key? key}) : super(key: key);

  @override
  _AudioPlayerTestWidgetState createState() => _AudioPlayerTestWidgetState();
}

class _AudioPlayerTestWidgetState extends State<AudioPlayerTestWidget> {
  late AudioPlayerTestModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AudioPlayerTestModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterFlowAudioPlayer(
      audio: Audio.network(
        'https://filesamples.com/samples/audio/mp3/sample3.mp3',
        metas: Metas(
          id: 'sample3.mp3-vyagg1nq',
        ),
      ),
      titleTextStyle: FlutterFlowTheme.of(context).bodyMedium.override(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
      playbackDurationTextStyle:
          FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'Poppins',
                color: Color(0xFF9D9D9D),
                fontSize: 12.0,
              ),
      fillColor: Color(0xFFEEEEEE),
      playbackButtonColor: FlutterFlowTheme.of(context).primary,
      activeTrackColor: Color(0xFF57636C),
      elevation: 4.0,
    );
  }
}
