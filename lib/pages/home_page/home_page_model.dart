import '/components/audio_player_test_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class HomePageModel extends FlutterFlowModel {
  ///  State fields for stateful widgets in this page.

  // Model for AudioPlayerTest component.
  late AudioPlayerTestModel audioPlayerTestModel;

  /// Initialization and disposal methods.

  void initState(BuildContext context) {
    audioPlayerTestModel = createModel(context, () => AudioPlayerTestModel());
  }

  void dispose() {
    audioPlayerTestModel.dispose();
  }

  /// Additional helper methods are added here.

}
