import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Rendre la barre de status transparente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  // Charger la préférence GPS sauvegardée
  await SettingsScreen.loadGpsPreference();
  
  // Enregistrer silencieusement l'installation (une seule fois)
  UpdateService.trackOrganicInstall();
  
  runApp(const SortirEnCorseApp());
}

class SortirEnCorseApp extends StatelessWidget {
  const SortirEnCorseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sortir en Corse Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
