import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../services/theme_provider.dart';

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
      final isUpdateAvailable =
          await UpdateService.isUpdateAvailable(serverInfo);
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
          content: Text(
              'Le cache de l\'application a été vidé. Redémarrez l\'application.',
              style: GoogleFonts.outfit()),
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
        await _inAppReview.openStoreListing(
            appStoreId: 'com.zeus2a.sortirencorse');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir la page d\'avis.',
                style: GoogleFonts.outfit()),
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
        if (updateInfo.updateAvailability ==
            UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
          return; // Succès, on s'arrête là
        }
      } catch (e) {
        debugPrint("Erreur InAppUpdate : $e");
        // En cas d'erreur ou si refusé, on "fallback" sur le lien normal ci-dessous
      }
    }

    // iOS ou Fallback Android : Ouverture classique du Store
    if (!mounted) return;
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
      _isLocationEnabled = SettingsScreen.isGpsEnabled &&
          serviceEnabled &&
          (permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse);
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
      bool hasPermission = (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse);
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

  Future<void> _rateApp() async {
    final InAppReview inAppReview = InAppReview.instance;
    try {
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        await inAppReview.openStoreListing(appStoreId: '6480579979');
      }
    } catch (e) {
      debugPrint('Error launching review: $e');
    }
  }

  void _showThemeSelector() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black26,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Apparence',
                        style: GoogleFonts.outfit(
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choisissez le thème de l\'application',
                        style: GoogleFonts.outfit(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildThemeOption(
                        icon: Icons.light_mode_rounded,
                        label: 'Clair',
                        isSelected: themeProvider.isLight,
                        isDark: isDark,
                        onTap: () {
                          themeProvider.setThemeMode(ThemeMode.light);
                          setModalState(() {});
                          HapticFeedback.selectionClick();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildThemeOption(
                        icon: Icons.dark_mode_rounded,
                        label: 'Sombre',
                        isSelected: themeProvider.isDark,
                        isDark: isDark,
                        onTap: () {
                          themeProvider.setThemeMode(ThemeMode.dark);
                          setModalState(() {});
                          HapticFeedback.selectionClick();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildThemeOption(
                        icon: Icons.smartphone_rounded,
                        label: 'Système',
                        isSelected: themeProvider.isSystem,
                        isDark: isDark,
                        onTap: () {
                          themeProvider.setThemeMode(ThemeMode.system);
                          setModalState(() {});
                          HapticFeedback.selectionClick();
                        },
                      ),
                      SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    const Color selectedBorder = Color(0xFFFF9E00);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.orange.withValues(alpha: 0.08))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? selectedBorder
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? selectedBorder.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? selectedBorder
                    : (isDark ? Colors.white54 : Colors.black54),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1A1A2E))
                    : (isDark ? Colors.white54 : Colors.black54),
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: selectedBorder, size: 22),
          ],
        ),
      ),
    );
  }

  String _getThemeLabel() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.isLight) return 'Clair';
    if (themeProvider.isDark) return 'Sombre';
    return 'Système';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Paramètres',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: MediaQuery.of(context).size.height * 0.02),
        children: [
          if (_updateInfo != null) _buildUpdateBanner(),
          if (_updateInfo != null)
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
            
          Text(
            'PRÉFÉRENCES',
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 12,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsGroup([
            _buildSettingTile(
              icon: Icons.palette_rounded,
              iconColor: const Color(0xFFFF9E00),
              title: 'Apparence',
              subtitle: _getThemeLabel(),
              onTap: _showThemeSelector,
              isFirst: true,
            ),
            _buildDivider(isDark),
            _buildSettingTile(
              icon: Icons.location_on_rounded,
              iconColor: Colors.blueAccent,
              title: 'Géolocalisation',
              subtitle: 'Trouver les événements à proximité',
              trailing: Switch(
                value: _isLocationEnabled,
                onChanged: _toggleLocation,
                activeThumbColor: Colors.blueAccent,
                activeTrackColor: Colors.blueAccent.withValues(alpha: 0.3),
                inactiveThumbColor: isDark ? Colors.white54 : Colors.grey,
                inactiveTrackColor: isDark ? Colors.white10 : Colors.black12,
              ),
              isLast: true,
            ),
          ], isDark),
          
          SizedBox(height: MediaQuery.of(context).size.height * 0.035),
          
          Text(
            'APPLICATION',
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 12,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsGroup([
            _buildSettingTile(
              icon: Icons.cleaning_services_rounded,
              iconColor: Colors.deepPurpleAccent,
              title: 'Vider le cache',
              subtitle: 'Forcer la mise à jour des événements',
              onTap: _clearCache,
              isFirst: true,
            ),
            _buildDivider(isDark),
            _buildSettingTile(
              icon: Icons.star_rounded,
              iconColor: Colors.yellow.shade700,
              title: 'Noter l\'application',
              subtitle: 'Laissez-nous un avis sur le store',
              onTap: _rateApp,
            ),
            _buildDivider(isDark),
            _buildSettingTile(
              icon: Icons.system_update_rounded,
              iconColor:
                  _updateInfo != null ? Colors.redAccent : Colors.orangeAccent,
              title: 'Mises à jour',
              subtitle: _updateInfo != null
                  ? 'Une mise à jour est disponible !'
                  : 'Votre application est à jour',
              trailing: _isCheckingUpdate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.orangeAccent))
                  : null,
              onTap: _updateInfo != null
                  ? _launchUpdateUrl
                  : () {
                      if (!_isCheckingUpdate) _checkForUpdates();
                      if (_updateInfo == null && !_isCheckingUpdate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Vous possédez déjà la dernière version.',
                                style: GoogleFonts.outfit()),
                            backgroundColor:
                                isDark ? Colors.white12 : Colors.black87,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
            ),
            _buildDivider(isDark),
            _buildSettingTile(
              icon: Icons.star_rounded,
              iconColor: Colors.amberAccent,
              title: 'Noter l\'application',
              subtitle: 'Laissez-nous un avis 5 étoiles ⭐',
              onTap: _requestReview,
            ),
            _buildDivider(isDark),
            _buildSettingTile(
              icon: Icons.shield_rounded,
              iconColor: Colors.greenAccent,
              title: 'Confidentialité et CGU',
              subtitle: 'Gérer vos données et conditions',
              onTap: () async {
                final Uri url =
                    Uri.parse('https://api.corsemusicevents.fr/privacy.html');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                }
              },
            ),
            _buildDivider(isDark),
            _buildSettingTile(
              icon: Icons.info_outline_rounded,
              iconColor: isDark ? Colors.white : Colors.black54,
              title: 'Version de l\'application',
              subtitle: _version,
              isLast: true,
            ),
          ], isDark),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
      indent: 64, // To align with text, bypassing icon
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: MediaQuery.of(context).size.height * 0.015),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          color: isDark ? Colors.white54 : Colors.black45,
                          fontSize: 13,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              if (trailing != null) trailing else if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white38 : Colors.black26,
                  size: 16,
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withValues(alpha: 0.2),
            Colors.orangeAccent.withValues(alpha: 0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.new_releases_rounded,
                    color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nouvelle version disponible !',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _updateInfo?.message ??
                'Une mise à jour importante est disponible pour Où Sortir en Corse.',
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Mettre à jour',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
