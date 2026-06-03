import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final bool forceUpdate;
  final String message;
  final String playStoreUrl;
  final String appStoreUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.forceUpdate,
    required this.message,
    required this.playStoreUrl,
    required this.appStoreUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latest_version'] ?? '1.0.0',
      buildNumber: json['build_number'] ?? 1,
      forceUpdate: json['force_update'] ?? false,
      message: json['message'] ?? '',
      playStoreUrl: json['play_store_url'] ?? '',
      appStoreUrl: json['app_store_url'] ?? '',
    );
  }
}

class UpdateService {
  static const String _versionUrl =
      'https://api.corsemusicevents.fr/?action=version';

  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse(_versionUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return UpdateInfo.fromJson(data['data']);
        }
      }
    } catch (e) {
      debugPrint('Erreur vérification mise à jour: $e');
    }
    return null;
  }

  static Future<bool> isUpdateAvailable(UpdateInfo serverInfo) async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      // Compare par numéro de build (plus fiable que la string de version)
      int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      return serverInfo.buildNumber > currentBuildNumber;
    } catch (e) {
      debugPrint('Erreur récupération version locale: $e');
      return false;
    }
  }

  static Future<void> trackOrganicInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasPinged = prefs.getBool('has_pinged_install') ?? false;

      if (!hasPinged) {
        String os = 'android';
        if (Platform.isIOS) os = 'ios';

        final trackUrl =
            'https://api.corsemusicevents.fr/?action=track_install&os=$os';
        final response = await http.get(Uri.parse(trackUrl));

        if (response.statusCode == 200) {
          await prefs.setBool('has_pinged_install', true);
        }
      }
    } catch (e) {
      debugPrint('Erreur tracking: $e');
    }
  }
}
