import 'package:flutter/material.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/phone_auth_screen.dart';
import 'presentation/screens/email_auth_screen.dart';
import 'presentation/screens/link_phone_screen.dart';  // NUOVO
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/profile_screen.dart';  // NUOVO
import 'main.dart' show navigatorKey;

class TravelShareApp extends StatelessWidget {
  const TravelShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelShare',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // ✅ Importante per deep link
      
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      
      // ROUTES AGGIORNATE
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/auth': (context) => const AuthScreen(),
        '/phone-login': (context) => const PhoneAuthScreen(),
        '/email-auth': (context) => const EmailAuthScreen(),
        '/link-phone': (context) => const LinkPhoneScreen(),  // NUOVO
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),  // NUOVO
      },
    );
  }
}