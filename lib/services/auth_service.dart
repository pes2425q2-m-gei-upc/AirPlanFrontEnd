import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth;

  // Constructor que permite inyectar una instancia personalizada de FirebaseAuth
  // lo que facilita la creación de mocks para testing
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  // Obtiene el usuario actual
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Obtiene el ID del usuario actual
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Obtiene el nombre de usuario actual
  String? getCurrentUsername() {
    return _auth.currentUser?.displayName;
  }

  // Verifica si el usuario está autenticado
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  // Escucha cambios en el estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Método para cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Método para iniciar sesión con correo y contraseña
  Future<UserCredential> signInWithEmailAndPassword(
      String email,
      String password,
      ) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Método para registrarse con correo y contraseña
  Future<UserCredential> createUserWithEmailAndPassword(
      String email,
      String password,
      ) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }



  // Método para iniciar sesión con un token personalizado
  Future<UserCredential> signInWithCustomToken(String token) {
    return _auth.signInWithCustomToken(token);
  }

  // Actualiza el nombre de usuario
  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  // Método para enviar un correo de restablecimiento de contraseña
  Future<void> resetPassword(String email) async {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // Método para enviar un correo de verificación
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // Método para actualizar la URL de la foto de perfil
  Future<void> updatePhotoURL(String photoURL) async {
    await _auth.currentUser?.updatePhotoURL(photoURL);
  }

  // Método para actualizar la contraseña
  Future<void> updatePassword(String newPassword) async {
    await _auth.currentUser?.updatePassword(newPassword);
  }

  // Método para reautenticar al usuario
  Future<UserCredential> reauthenticateWithCredential(
      AuthCredential credential,
      ) async {
    if (_auth.currentUser == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No user is currently signed in',
      );
    }
    return await _auth.currentUser!.reauthenticateWithCredential(credential);
  }

  // Método para crear una credencial de email y contraseña

  // Método para recargar el usuario actual
  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  // Método para eliminar la cuenta del usuario actual
  Future<void> deleteCurrentUser() async {
    await _auth.currentUser?.delete();
  }

  Future<UserCredential> signInWithPopup(GithubAuthProvider githubProvider) async {
    return await _auth.signInWithPopup(githubProvider);
  }

  Future<UserCredential> signInWithProvider(GithubAuthProvider githubProvider) async {
    return await _auth.signInWithProvider(githubProvider);
  }
}