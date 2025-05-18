import 'package:flutter/material.dart';
import 'form_content_register.dart';
import 'logo_widget.dart';
import 'rive_controller.dart';
import 'services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';

class SignUpPage extends StatelessWidget {
  // Añadimos la posibilidad de inyectar el AuthService
  final AuthService? authService;

  const SignUpPage({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final RiveAnimationControllerHelper riveHelper =
        RiveAnimationControllerHelper();

    // Pasamos el authService inyectado al FormContentRegister
    final formContent = FormContentRegister(
      riveHelper: riveHelper,
      authService: authService,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('signup_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child:
            isSmallScreen
                ? SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [LogoWidget(riveHelper: riveHelper), formContent],
                  ),
                )
                : Container(
                  padding: const EdgeInsets.all(32.0),
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Row(
                    children: [
                      Expanded(child: LogoWidget(riveHelper: riveHelper)),
                      Expanded(child: Center(child: formContent)),
                    ],
                  ),
                ),
      ),
    );
  }
}
