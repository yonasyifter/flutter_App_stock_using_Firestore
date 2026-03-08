import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart' as ap;
import 'providers/language_provider.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // After running `flutterfire configure` replace the line above with:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const StockBookApp());
}

class StockBookApp extends StatelessWidget {
  const StockBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ap.AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, lang, _) {
          return MaterialApp(
            title: lang.isAmharic ? 'ስቶክቡክ' : 'StockBook',
            theme: AppTheme.theme,
            debugShowCheckedModeBanner: false,
            locale: lang.isAmharic
                ? const Locale('am', 'ET')
                : const Locale('en', 'US'),
            supportedLocales: const [
              Locale('am', 'ET'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

/// AuthWrapper watches the auth state and shows the right screen.
/// - unknown  → loading spinner (Firebase is initializing)
/// - authenticated → HomeScreen
/// - unauthenticated → LoginScreen
/// No manual Navigator.push needed — this widget rebuilds automatically
/// whenever the user signs in or out.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();

    switch (auth.status) {
      case ap.AuthStatus.unknown:
        // Firebase hasn't confirmed auth state yet — show splash
        return const Scaffold(
          backgroundColor: AppTheme.ink,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BrandSplash(),
                SizedBox(height: 40),
                CircularProgressIndicator(color: AppTheme.amber),
              ],
            ),
          ),
        );

      case ap.AuthStatus.authenticated:
        return const HomeScreen();

      case ap.AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

class _BrandSplash extends StatelessWidget {
  const _BrandSplash();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('ስቶክ',
            style: AppTheme.serifAmharic(
                fontSize: 40, fontWeight: FontWeight.w900, color: AppTheme.cream)),
        Text('ቡክ',
            style: AppTheme.serifAmharic(
                fontSize: 40, fontWeight: FontWeight.w900, color: AppTheme.amberLight)),
      ],
    );
  }
}
