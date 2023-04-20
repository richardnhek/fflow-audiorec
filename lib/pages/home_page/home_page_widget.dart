import '/components/audio_player_test_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({Key? key}) : super(key: key);

  @override
  _HomePageWidgetState createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _unfocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
  }

  @override
  void dispose() {
    _model.dispose();

    _unfocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return GestureDetector(
    //   onTap: () => FocusScope.of(context).requestFocus(_unfocusNode),
    //   child: Scaffold(
    //     key: scaffoldKey,
    //     backgroundColor: Colors.white,
    //     body: SafeArea(
    //       child: Column(
    //         mainAxisSize: MainAxisSize.max,
    //         crossAxisAlignment: CrossAxisAlignment.stretch,
    //         children: [
    // Container(
    //   width: 200.0,
    //   height: 200.0,
    //   child: custom_widgets.AudioRecorderAndPlayerTest(
    //     width: 200.0,
    //     height: 200.0,
    //   ),
    // ),
    // Container(
    //   width: 200.0,
    //   height: 200.0,
    //   child: custom_widgets.AudioRecorderFlutterSound(
    //     width: 200.0,
    //     height: 200.0,
    //   ),
    // ),
    // return custom_widgets.VideoRecorder();
    return Center(child: custom_widgets.VideoRecorder());
    // Container(
    //   width: 400,
    //   height: 200,
    //   child: custom_widgets.VideoRecorderTest(
    //     width: 200.0,
    //     height: 200.0,
    //   ),
    // ),
    // wrapWithModel(
    //   model: _model.audioPlayerTestModel,
    //   updateCallback: () => setState(() {}),
    //   child: AudioPlayerTestWidget(),
    // ),
    //         ],
    //       ),
    //     ),
    //   ),
    // );
  }
}
