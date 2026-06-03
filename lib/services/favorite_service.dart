import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService {
  static const String _favoritesKey = 'favorite_events';
  static final ValueNotifier<List<String>> favoritesNotifier = ValueNotifier<List<String>>([]);

  /// Initialise la liste des favoris depuis SharedPreferences
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedFavorites = prefs.getStringList(_favoritesKey) ?? [];
    favoritesNotifier.value = savedFavorites;
  }

  /// Vérifie si un événement est en favori
  static bool isFavorite(String eventId) {
    return favoritesNotifier.value.contains(eventId);
  }

  /// Ajoute ou supprime un événement des favoris
  static Future<void> toggleFavorite(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> currentFavorites = List.from(favoritesNotifier.value);

    if (currentFavorites.contains(eventId)) {
      currentFavorites.remove(eventId);
    } else {
      currentFavorites.add(eventId);
    }

    await prefs.setStringList(_favoritesKey, currentFavorites);
    favoritesNotifier.value = currentFavorites;
  }
}
