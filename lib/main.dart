import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'services/update_service.dart';
import 'services/theme_provider.dart';
import 'services/favorite_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FavoriteService.init();

  // Rendre la barre de status et navigation transparentes
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  // Charger la préférence GPS sauvegardée
  await SettingsScreen.loadGpsPreference();

  // Enregistrer silencieusement l'installation (une seule fois)
  UpdateService.trackOrganicInstall();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const SortirEnCorseApp(),
    ),
  );
}

class SortirEnCorseApp extends StatelessWidget {
  const SortirEnCorseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Sortir en Corse Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      home: const SplashScreen(),
    );
  }
}
