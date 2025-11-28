import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'localization.dart'; // Импортируем наш словарь

// Глобальная переменная для темы
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Слушаем изменения ТЕМЫ
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {

        // 2. Слушаем изменения ЯЗЫКА (Вложенный билдер)
        return ValueListenableBuilder<String>(
          valueListenable: languageNotifier,
          builder: (_, String currentLang, __) {

            return MaterialApp(
              title: 'FLUX Analytics',
              debugShowCheckedModeBanner: false,

              // --- ТЕМЫ (оставляем как было) ---
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: Colors.grey[100],
                primaryColor: Colors.blueAccent,
                textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
                appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
                bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Colors.white, selectedItemColor: Colors.blueAccent, unselectedItemColor: Colors.grey),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: Colors.black,
                primaryColor: Colors.blueAccent[100],
                textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(bodyColor: Colors.white, displayColor: Colors.white),
                inputDecorationTheme: InputDecorationTheme(hintStyle: TextStyle(color: Colors.grey[500])),
                appBarTheme: const AppBarTheme(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
                bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: Colors.grey[900], selectedItemColor: Colors.blueAccent[100], unselectedItemColor: Colors.grey),
              ),
              themeMode: currentMode,

              home: const AuthWrapper(),
            );
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return const HomeScreen();
        return const LoginScreen();
      },
    );
  }
}