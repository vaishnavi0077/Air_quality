import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'view/login.dart';
import 'view/splash.dart';
import 'view/home.dart';
import 'view/form.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: kIsWeb
        ? const FirebaseOptions(
            apiKey: "AIzaSyCCP5QLC-HrYugxD2gbUJA7MLuKG3Fi7oQ",
            authDomain: "aqi-monitoring-41cda.firebaseapp.com",
            projectId: "aqi-monitoring-41cda",
            storageBucket: "aqi-monitoring-41cda.firebasestorage.app",
            messagingSenderId: "385398857892",
            appId: "1:385398857892:web:5f447768ce2eaa23cb0631",
          )
        : null,
  );
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Guard',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      
      // Set initial route to splash screen
      initialRoute: '/',
      
      // Define your routes
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/health-profile': (context) => HealthProfileForm(),
        '/dashboard': (context) => HomeScreen(),
        
      },
    );
  }
}