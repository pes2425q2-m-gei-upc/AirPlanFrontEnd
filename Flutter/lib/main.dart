import 'package:flutter/material.dart';
import 'package:prueba_flutter/login_page.dart';
import 'register.dart';  // Importa la pantalla de registre
import 'package:firebase_core/firebase_core.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
        apiKey: "AIzaSyDjyHcnvD1JTfN7xpkRMD-S_qDMSnvbZII",
        authDomain: "airplan-f08be.firebaseapp.com",
        projectId: "airplan-f08be",
        storageBucket: "airplan-f08be.firebasestorage.app",
        messagingSenderId: "952401482773",
        appId: "1:952401482773:web:9f9a3484c2cce60970ea1c",
        measurementId: "G-L70Y1N6J8Z"
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Auth',
      home: LoginPage(),
    );
  }
}
