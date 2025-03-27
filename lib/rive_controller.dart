import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class RiveAnimationControllerHelper {
  static final RiveAnimationControllerHelper _instance =
  RiveAnimationControllerHelper._internal();

  factory RiveAnimationControllerHelper() => _instance;

  RiveAnimationControllerHelper._internal();

  Artboard? _riveArtboard;

  late RiveAnimationController _controllerIdle;
  late RiveAnimationController _controllerHandsUp;
  late RiveAnimationController _controllerHandsDown;
  late RiveAnimationController _controllerSuccess;
  late RiveAnimationController _controllerFail;
  late RiveAnimationController _controllerLookDownRight;
  late RiveAnimationController _controllerLookDownLeft;

  bool isLookingRight = false;
  bool isLookingLeft = false;
  bool isHandsUp = false;

  Artboard? get riveArtboard => _riveArtboard;

  void initialize(Artboard artboard) {
    _riveArtboard = artboard;

    // Inicializa todos los controladores
    _controllerIdle = SimpleAnimation('idle');
    _controllerHandsUp = SimpleAnimation('Hands_up');
    _controllerHandsDown = SimpleAnimation('hands_down');
    _controllerSuccess = SimpleAnimation('success');
    _controllerFail = SimpleAnimation('fail');
    _controllerLookDownRight = SimpleAnimation('Look_down_right');
    _controllerLookDownLeft = SimpleAnimation('Look_down_left');

    // Establece la animación inicial
    _riveArtboard?.addController(_controllerIdle);
  }

  // Métodos para controlar animaciones específicas
  void setHandsUp() {
    if (!isHandsUp) {
      removeAllControllers();
      _riveArtboard?.addController(_controllerHandsUp);
      isHandsUp = true;
    }
  }

  void setHandsDown() {
    removeAllControllers();
    _riveArtboard?.addController(_controllerHandsDown);
    isHandsUp = false;
  }

  void setLookRight() {
    if (!isLookingRight) {
      removeAllControllers();
      _riveArtboard?.addController(_controllerLookDownRight);
      isLookingRight = true;
      isLookingLeft = false;
    }
  }

  void setLookLeft() {
    if (!isLookingLeft) {
      removeAllControllers();
      _riveArtboard?.addController(_controllerLookDownLeft);
      isLookingLeft = true;
      isLookingRight = false;
    }
  }

  void setIdle() {
    removeAllControllers();
    _riveArtboard?.addController(_controllerIdle);
    resetState();
  }

  void resetState() {
    isLookingRight = false;
    isLookingLeft = false;
    isHandsUp = false;
  }

  // Métodos existentes (se mantienen igual)
  void addController(RiveAnimationController controller) {
    removeAllControllers();
    _riveArtboard?.addController(controller);
  }

  void addDownLeftController() => setLookLeft();

  void addDownRightController() => setLookRight();

  void addFailController() => addController(_controllerFail);

  void addHandsDownController() => addController(_controllerHandsDown);

  void addHandsUpController() => setHandsUp();

  void addSuccessController() => addController(_controllerSuccess);

  Future<void> loadRiveFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final file = RiveFile.import(data);
    _riveArtboard = file.mainArtboard;

    // Inicializar todos los controladores
    _controllerIdle = SimpleAnimation('idle');
    _controllerHandsUp = SimpleAnimation('Hands_up');
    _controllerHandsDown = SimpleAnimation('hands_down');
    _controllerSuccess = SimpleAnimation('success');
    _controllerFail = SimpleAnimation('fail');
    _controllerLookDownRight = SimpleAnimation('Look_down_right');
    _controllerLookDownLeft = SimpleAnimation('Look_down_left');

    // Estado inicial
    _riveArtboard?.addController(_controllerIdle);
  }

  void removeAllControllers() {
    final controllers = [
      _controllerIdle,
      _controllerHandsUp,
      _controllerHandsDown,
      _controllerSuccess,
      _controllerFail,
      _controllerLookDownRight,
      _controllerLookDownLeft,
    ];

    for (final controller in controllers) {
      _riveArtboard?.removeController(controller);
    }
  }

  void dispose() {
    removeAllControllers();
    _controllerIdle.dispose();
    _controllerHandsUp.dispose();
    _controllerHandsDown.dispose();
    _controllerSuccess.dispose();
    _controllerFail.dispose();
    _controllerLookDownRight.dispose();
    _controllerLookDownLeft.dispose();
  }
}