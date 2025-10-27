import 'package:flutter/material.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/flight_test_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/screens/auth_screen.dart';

// navigatorKey per eventuali redirect futuri (opzionale)
class AppNavigator { static final key = GlobalKey<NavigatorState>(); }

class TravelShareApp extends StatelessWidget {
  const TravelShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bool demoMode = true; // ⬅️ METTILO A true per bypass login

    return MaterialApp(
      title: 'TravelShare',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.key,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),

      // ⬇️ se demoMode è true vai diretto alla UI
      initialRoute: '/home',

      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/auth'   : (_) => const AuthScreen(),
        '/home'   : (_) => const HomeShell(),
        '/map'    : (_) => const MapScreen(),
        '/flight-test': (_) => const FlightTestScreen(),
      },
    );
  }
}
