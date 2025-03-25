import 'package:flutter/material.dart';
import 'form_content_register.dart';
import 'logo_widget.dart';
import 'rive_controller.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final RiveAnimationControllerHelper riveHelper = RiveAnimationControllerHelper();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registre"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: isSmallScreen
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoWidget(riveHelper: riveHelper),
            FormContentRegister(riveHelper: riveHelper),
          ],
        )
            : Container(
          padding: const EdgeInsets.all(32.0),
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            children: [
              Expanded(child: LogoWidget(riveHelper: riveHelper)),
              Expanded(
                child: Center(child: FormContentRegister(riveHelper: riveHelper)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}