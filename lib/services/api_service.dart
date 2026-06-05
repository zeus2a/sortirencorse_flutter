import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart';
import '../models/network_item.dart';

/// Résultat du chargement — contient les events + l'origine des données
class EventLoadResult {
  final List<Event> events;
  /// true si les données viennent du cache local (réseau indisponible)
  final bool isFromCache;
  /// Date du dernier refresh réseau réussi (null si jamais synchronisé)
  final DateTime? cachedAt;

  const EventLoadResult({
    required this.events,
    required this.isFromCache,
    this.cachedAt,
  });
}

class ApiService {
  static const String baseUrl = 'https://api.corsemusicevents.fr';
  static const String cacheKey = 'cme_events_cache';
  static const String cacheTimestampKey = 'cme_events_cache_ts';

  /// Durée de validité du cache : 6 heures
  static const Duration cacheTTL = Duration(hours: 6);

  // ── Helpers timestamp ──────────────────────────────────────────

  /// Retourne la date de la dernière mise en cache, ou null
  Future<DateTime?> getCacheTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(cacheTimestampKey);
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  /// Retourne true si le cache a plus de [cacheTTL] ou n'existe pas
  Future<bool> isCacheStale() async {
    final ts = await getCacheTimestamp();
    if (ts == null) return true;
    return DateTime.now().difference(ts) > cacheTTL;
  }

  // ── Lecture cache ──────────────────────────────────────────────

  /// Lit les événements depuis SharedPreferences (instantané)
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

  // ── Écriture cache ─────────────────────────────────────────────

  Future<void> _saveToCache(List<dynamic> rawData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, json.encode(rawData));
      await prefs.setString(
          cacheTimestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Erreur écriture cache: $e');
    }
  }

  // ── Fetch principal ─────────────────────────────────────────────

  /// Récupère les événements depuis le serveur et met à jour le cache.
  /// Lance une exception si le réseau est indisponible.
  Future<List<Event>> fetchEvents() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/?action=events'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        List<dynamic> data = jsonResponse['data'] ?? [];

        if (data.isNotEmpty) {
          await _saveToCache(data);
        }

        return data.map((item) => Event.fromJson(item)).toList();
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// ★ Méthode principale hors-ligne intelligente ★
  ///
  /// Stratégie :
  /// 1. Charge le cache en mémoire instantanément (affichage immédiat)
  /// 2. Essaie de rafraîchir depuis le réseau en arrière-plan
  /// 3. Si le réseau échoue → retourne les données du cache avec [isFromCache] = true
  /// 4. Si aucun cache ET réseau KO → lève une exception
  Future<EventLoadResult> fetchWithFallback() async {
    // Étape 1 : récupérer le cache existant
    final cached = await getCachedEvents();
    final ts = await getCacheTimestamp();

    // Étape 2 : tenter le réseau
    try {
      final fresh = await fetchEvents();
      return EventLoadResult(
        events: fresh,
        isFromCache: false,
        cachedAt: null,
      );
    } catch (_) {
      // Réseau KO
      if (cached.isNotEmpty) {
        debugPrint('[Cache] Mode hors-ligne — ${cached.length} événements depuis le cache');
        return EventLoadResult(
          events: cached,
          isFromCache: true,
          cachedAt: ts,
        );
      }
      // Ni réseau, ni cache → erreur réelle
      rethrow;
    }
  }

  // ── Venues & Prestataires ──────────────────────────────────────

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
