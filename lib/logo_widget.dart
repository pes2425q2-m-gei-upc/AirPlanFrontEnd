import 'package:flutter/material.dart';
import 'rive_controller.dart';
import 'rive_animation_widget.dart';
import 'package:easy_localization/easy_localization.dart';

class LogoWidget extends StatelessWidget {
  final RiveAnimationControllerHelper riveHelper;

  const LogoWidget({super.key, required this.riveHelper});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: isSmallScreen ? 200 : 300,
          height: isSmallScreen ? 200 : 300,
          child: RiveAnimationWidget(riveHelper: riveHelper),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "welcome_airplan".tr(),
            textAlign: TextAlign.center,
            style:
                isSmallScreen
                    ? Theme.of(context).textTheme.headlineMedium
                    : Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.black),
          ),
        ),
      ],
    );
  }
}
