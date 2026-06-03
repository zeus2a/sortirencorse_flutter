import 'package:geolocator/geolocator.dart';
import '../models/event.dart';

class SmartSearch {
  static String _normalize(String input) {
    var withDia =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';

    String str = input.toLowerCase();
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str.trim();
  }

  static Future<List<Event>> processEvents({
    required List<Event> allEvents,
    required String query,
    Position? userPosition,
  }) async {
    final normalizedQuery = _normalize(query);
    final isSearchEmpty = normalizedQuery.isEmpty;

    List<Event> processedList = allEvents.map((event) {
      double? distance;
      // Calculate distance if user location is known and event has valid coordinates
      if (userPosition != null && event.lat != 0.0 && event.lng != 0.0) {
        final distanceInMeters = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          event.lat,
          event.lng,
        );
        distance = distanceInMeters / 1000.0; // Convert to km
      }
      return event.copyWith(distance: distance);
    }).toList();

    // Filter by query if not empty
    if (!isSearchEmpty) {
      final queryWords = normalizedQuery.split(' ');

      processedList = processedList.where((event) {
        final searchString = _normalize(
          '${event.title} ${event.locationAddress} ${event.segmentLabel} ${event.description}',
        );

        // Simple logic: all words in the query must be found in the event's data
        bool matchesAll = true;
        for (final word in queryWords) {
          if (word.isEmpty) continue;
          if (!searchString.contains(word)) {
            matchesAll = false;
            break;
          }
        }
        return matchesAll;
      }).toList();
    }

    // Sort the list
    processedList.sort((a, b) {
      if (a.distance != null && b.distance != null) {
        bool aNear = a.distance! <= 25.0;
        bool bNear = b.distance! <= 25.0;
        
        if (aNear && bNear) {
          // Both are within 25km, sort by date
          return a.dateStart.compareTo(b.dateStart);
        } else if (aNear && !bNear) {
          return -1; // a is near, so it comes first
        } else if (!aNear && bNear) {
          return 1; // b is near, so it comes first
        } else {
          // Both are farther than 25km, sort by date
          return a.dateStart.compareTo(b.dateStart);
        }
      }

      // If only one has distance, it goes first
      if (a.distance != null && b.distance == null) return -1;
      if (a.distance == null && b.distance != null) return 1;

      // Otherwise, sort chronologically
      return a.dateStart.compareTo(b.dateStart);
    });

    return processedList;
  }
}
