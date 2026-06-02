import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:in_app_review/in_app_review.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  static bool isGpsEnabled = true;
  static const String _gpsKey = 'gps_enabled';

  /// Charge la préférence GPS sauvegardée (appelé au démarrage de l'app)
  static Future<void> loadGpsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    isGpsEnabled = prefs.getBool(_gpsKey) ?? true;
  }

  /// Sauvegarde la préférence GPS
  static Future<void> saveGpsPreference(bool value) async {
    isGpsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gpsKey, value);
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLocationEnabled = false;
  String _version = "Chargement...";
  UpdateInfo? _updateInfo;
  bool _isCheckingUpdate = false;
  final InAppReview _inAppReview = InAppReview.instance;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkLocationStatus();
    _checkForUpdates();
  }

  Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = "${info.version} (Build ${info.buildNumber})";
      });
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingUpdate = true;
    });
    
    final serverInfo = await UpdateService.checkForUpdates();
    if (serverInfo != null) {
      final isUpdateAvailable = await UpdateService.isUpdateAvailable(serverInfo);
      if (isUpdateAvailable) {
        setState(() {
          _updateInfo = serverInfo;
        });
      }
    }
    
    setState(() {
      _isCheckingUpdate = false;
    });
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiService.cacheKey);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le cache de l\'application a été vidé. Redémarrez l\'application.', style: GoogleFonts.outfit()),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _requestReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing(appStoreId: 'com.zeus2a.sortirencorse');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir la page d\'avis.', style: GoogleFonts.outfit()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _launchUpdateUrl() async {
    // Si Android, on tente la mise à jour silencieuse / intégrée
    if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
        if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
          return; // Succès, on s'arrête là
        }
      } catch (e) {
        print("Erreur InAppUpdate : $e");
        // En cas d'erreur ou si refusé, on "fallback" sur le lien normal ci-dessous
      }
    }

    // iOS ou Fallback Android : Ouverture classique du Store
    final url = Theme.of(context).platform == TargetPlatform.iOS 
        ? _updateInfo?.appStoreUrl 
        : _updateInfo?.playStoreUrl;
        
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _checkLocationStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    
    setState(() {
      _isLocationEnabled = SettingsScreen.isGpsEnabled && serviceEnabled && 
          (permission == LocationPermission.always || permission == LocationPermission.whileInUse);
    });
  }

  Future<void> _toggleLocation(bool value) async {
    if (value) {
      LocationPermission currentPerm = await Geolocator.checkPermission();
      
      // CORRECTION iOS/iPhone: Ouvre les réglages de l'app si refusé définitivement
      if (currentPerm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      LocationPermission permission = await Geolocator.requestPermission();
      bool hasPermission = (permission == LocationPermission.always || permission == LocationPermission.whileInUse);
      if (hasPermission) {
        await SettingsScreen.saveGpsPreference(true);
      } else if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      }
      
      setState(() {
        _isLocationEnabled = hasPermission;
      });
    } else {
      // In-app disable (user friendly, no OS settings)
      await SettingsScreen.saveGpsPreference(false);
      setState(() {
        _isLocationEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Paramètres',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_updateInfo != null)
            _buildUpdateBanner(),
          if (_updateInfo != null)
            const SizedBox(height: 24),
          Text(
            'PRÉFÉRENCES',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, letterSpacing: 2.0),
          ),
          const SizedBox(height: 16),
          _buildSettingTile(
            icon: Icons.location_on_rounded,
            iconColor: Colors.blueAccent,
            title: 'Géolocalisation',
            subtitle: 'Trouver les événements à proximité',
            trailing: Switch(
              value: _isLocationEnabled,
              onChanged: _toggleLocation,
              activeColor: Colors.blueAccent,
              activeTrackColor: Colors.blueAccent.withOpacity(0.3),
              inactiveThumbColor: Colors.white54,
              inactiveTrackColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'APPLICATION',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, letterSpacing: 2.0),
          ),
          const SizedBox(height: 16),
          _buildSettingTile(
            icon: Icons.cleaning_services_rounded,
            iconColor: Colors.deepPurpleAccent,
            title: 'Vider le cache',
            subtitle: 'Forcer la mise à jour des événements',
            onTap: _clearCache,
          ),
          _buildSettingTile(
            icon: Icons.system_update_rounded,
            iconColor: _updateInfo != null ? Colors.redAccent : Colors.orangeAccent,
            title: 'Mises à jour',
            subtitle: _updateInfo != null ? 'Une mise à jour est disponible !' : 'Votre application est à jour',
            trailing: _isCheckingUpdate 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent))
                : null,
            onTap: _updateInfo != null 
                ? _launchUpdateUrl 
                : () {
                    if (!_isCheckingUpdate) _checkForUpdates();
                    if (_updateInfo == null && !_isCheckingUpdate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Vous possédez déjà la dernière version.', style: GoogleFonts.outfit()),
                          backgroundColor: Colors.white12,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
          _buildSettingTile(
            icon: Icons.star_rounded,
            iconColor: Colors.amberAccent,
            title: 'Noter l\'application',
            subtitle: 'Laissez-nous un avis 5 étoiles ⭐',
            onTap: _requestReview,
          ),
          _buildSettingTile(
            icon: Icons.shield_rounded,
            iconColor: Colors.greenAccent,
            title: 'Confidentialité',
            subtitle: 'Gérer vos données personnelles',
            onTap: () async {
              final Uri url = Uri.parse('https://api.corsemusicevents.fr/privacy.html');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
          _buildSettingTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.white,
            title: 'Version de l\'application',
            subtitle: _version,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
              )
            : null,
        trailing: trailing ?? (onTap != null ? const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16) : null),
      ),
    );
  }

  Widget _buildUpdateBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.redAccent.withOpacity(0.2), Colors.orangeAccent.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.new_releases_rounded, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nouvelle version disponible !',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _updateInfo?.message ?? 'Une mise à jour importante est disponible pour Où Sortir en Corse.',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _launchUpdateUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Mettre à jour', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
