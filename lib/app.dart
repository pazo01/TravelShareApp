import 'package:flutter/material.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/phone_auth_screen.dart';
import 'presentation/screens/email_auth_screen.dart';
import 'presentation/screens/link_phone_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'main.dart' show navigatorKey;

import 'core/config/route_observer.dart'; // ✅ import RouteObserver

class TravelShareApp extends StatelessWidget {
  const TravelShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelShare',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      navigatorObservers: [
        routeObserver,    // ✅ ACTIVATE ROUTE OBSERVER HERE
      ],

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

      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomeScreen(),
        '/auth': (_) => const AuthScreen(),
        '/phone-login': (_) => const PhoneAuthScreen(),
        '/email-auth': (_) => const EmailAuthScreen(),
        '/link-phone': (_) => const LinkPhoneScreen(),
        '/home': (_) => const HomeScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}
