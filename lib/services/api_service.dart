import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/network_item.dart';

class ApiService {
  static const String baseUrl = 'https://api.corsemusicevents.fr';
  static const String cacheKey = 'cme_events_cache';

  // Récupère les événements depuis la mémoire locale (Instantané)
  Future<List<Event>> getCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        List<dynamic> data = json.decode(cachedData);
        return data.map((item) => Event.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Erreur lecture cache: $e');
    }
    return [];
  }

  // Récupère les événements depuis le serveur O2Switch et met à jour le cache
  Future<List<Event>> fetchEvents() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/?action=events'));

      if (response.statusCode == 200) {
        // Sauvegarde silencieuse en local
        final prefs = await SharedPreferences.getInstance();

        // On vérifie que la donnée est bien du JSON valide et non vide
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        List<dynamic> data = jsonResponse['data'] ?? [];

        if (data.isNotEmpty) {
          await prefs.setString(cacheKey, json.encode(data));
        }

        return data.map((item) => Event.fromJson(item)).toList();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Récupération des Lieux (Venues)
  Future<List<NetworkItem>> fetchVenues() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/?action=venues'));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => NetworkItem.fromJson(item, 'event_venue'))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur fetchVenues: $e');
      return [];
    }
  }

  // Récupération des Prestataires (profils UserPro)
  Future<List<NetworkItem>> fetchPrestataires() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/?action=prestataires'));
      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        List<dynamic> data = jsonResponse['data'] ?? [];
        return data.map((item) => NetworkItem.fromPrestataire(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur fetchPrestataires: $e');
      return [];
    }
  }
}
