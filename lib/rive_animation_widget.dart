import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'rive_controller.dart';

class RiveAnimationWidget extends StatefulWidget {
  final RiveAnimationControllerHelper riveHelper;

  const RiveAnimationWidget({super.key, required this.riveHelper});

  @override
  State<RiveAnimationWidget> createState() => _RiveAnimationWidgetState();
}

class _RiveAnimationWidgetState extends State<RiveAnimationWidget> {
  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      'assets/animations/headless_bear.riv',
      onInit: (artboard) {
        widget.riveHelper.initialize(artboard); // Ahora este método existe
      },
      fit: BoxFit.contain,
    );
  }
}