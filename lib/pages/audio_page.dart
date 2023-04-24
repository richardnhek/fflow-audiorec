import 'package:flutter/material.dart';
import 'package:lyfted_demo/custom_code/widgets/index.dart';
import 'package:lyfted_demo/index.dart';

class AudioPage extends StatefulWidget {
  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AudioRecorderAndAnimation(
          height: 400,
          width: MediaQuery.of(context).size.height,
        ),
      ],
    );
  }
}
