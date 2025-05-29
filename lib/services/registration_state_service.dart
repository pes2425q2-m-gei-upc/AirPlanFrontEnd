import 'dart:async';

/// Servicio para gestionar el estado del registro y evitar problemas de timing
class RegistrationStateService {
  static final RegistrationStateService _instance =
      RegistrationStateService._internal();
  factory RegistrationStateService() => _instance;
  RegistrationStateService._internal();

  final StreamController<RegistrationState> _stateController =
      StreamController<RegistrationState>.broadcast();

  RegistrationState _currentState = RegistrationState.idle;
  String? _registrationEmail;

  Stream<RegistrationState> get stateStream => _stateController.stream;
  RegistrationState get currentState => _currentState;
  String? get registrationEmail => _registrationEmail;

  void startRegistration(String email) {
    _registrationEmail = email;
    _setState(RegistrationState.registering);
  }

  void markRegistrationComplete() {
    _setState(RegistrationState.completed);
  }

  void markRegistrationFailed() {
    _setState(RegistrationState.failed);
    _registrationEmail = null;
  }

  void reset() {
    _setState(RegistrationState.idle);
    _registrationEmail = null;
  }

  void _setState(RegistrationState newState) {
    _currentState = newState;
    _stateController.add(_currentState);
  }

  bool isRegistering(String? email) {
    return _currentState == RegistrationState.registering &&
        _registrationEmail == email;
  }

  void dispose() {
    _stateController.close();
  }
}

enum RegistrationState { idle, registering, completed, failed }
