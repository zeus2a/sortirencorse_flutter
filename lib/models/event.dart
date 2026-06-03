import 'package:flutter/material.dart';

class Event {
  static Map<String, dynamic> getCategoryStyle(String label) {
    final lowerLabel = label.toLowerCase();
    
    if (lowerLabel.contains('party') || lowerLabel.contains('soir') || lowerLabel.contains('dj') || lowerLabel.contains('bar')) {
      return {'color': Colors.purple, 'icon': Icons.nightlife_rounded};
    } else if (lowerLabel.contains('concert') || lowerLabel.contains('live') || lowerLabel.contains('musique')) {
      return {'color': Colors.redAccent, 'icon': Icons.mic_external_on_rounded};
    } else if (lowerLabel.contains('animation')) {
      return {'color': Colors.orangeAccent, 'icon': Icons.celebration_rounded};
    } else if (lowerLabel.contains('festival')) {
      return {'color': Colors.blueAccent, 'icon': Icons.festival_rounded};
    } else if (lowerLabel.contains('théâtre') || lowerLabel.contains('theatre') || lowerLabel.contains('culture')) {
      return {'color': Colors.tealAccent, 'icon': Icons.theater_comedy_rounded};
    } else if (lowerLabel.contains('polyphonie')) {
      return {'color': Colors.indigoAccent, 'icon': Icons.record_voice_over_rounded};
    } else {
      return {'color': const Color(0xFFFF9E00), 'icon': Icons.event_rounded};
    }
  }

  final int id;
  final String title;
  final String slug;
  final String link;
  final String description;
  final DateTime dateStart;
  final String dateFormatted;
  final String locationAddress;
  final double lat;
  final double lng;
  final String imageUrl;
  final String segment;
  final String segmentLabel;
  final String source;
  final double? distance; // Distance in kilometers from the user

  Event({
    required this.id,
    required this.title,
    required this.slug,
    required this.link,
    required this.description,
    required this.dateStart,
    required this.dateFormatted,
    required this.locationAddress,
    required this.lat,
    required this.lng,
    required this.imageUrl,
    required this.segment,
    required this.segmentLabel,
    required this.source,
    this.distance,
  });

  Event copyWith({
    double? distance,
  }) {
    return Event(
      id: id,
      title: title,
      slug: slug,
      link: link,
      description: description,
      dateStart: dateStart,
      dateFormatted: dateFormatted,
      locationAddress: locationAddress,
      lat: lat,
      lng: lng,
      imageUrl: imageUrl,
      segment: segment,
      segmentLabel: segmentLabel,
      source: source,
      distance: distance ?? this.distance,
    );
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    final niche = json['niche'] as Map<String, dynamic>? ?? {};

    DateTime parsedDate;
    try {
      if (json['date_start'] != null &&
          json['date_start'].toString().isNotEmpty) {
        String dateStr = json['date_start'].toString();
        // If the date is in DD/MM/YYYY format, convert it to YYYY-MM-DD
        if (dateStr.contains('/') && dateStr.length == 10) {
          List<String> parts = dateStr.split('/');
          if (parts.length == 3) {
            dateStr = '${parts[2]}-${parts[1]}-${parts[0]}';
          }
        }

        // Ensure standard ISO-8601 format (replace space with T)
        dateStr = dateStr.replaceAll(' ', 'T');

        parsedDate = DateTime.parse(dateStr);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (_) {
      parsedDate = DateTime.now();
    }

    String sourceRaw = json['source'] ?? '';
    String sourceFriendly = sourceRaw;
    if (sourceRaw.toLowerCase() == 'wp_event_manager' ||
        sourceRaw.toLowerCase() == 'wp-event-manager') {
      sourceFriendly = 'Corse Music Events';
    } else if (sourceRaw.toLowerCase() == 'eventon') {
      sourceFriendly = 'Art & Âme Corse';
    }

    String finalSegment = niche['segment'] ?? '';
    String finalLabel = niche['label'] ?? '';

    // Mappage des types d'événements
    if (sourceRaw.toLowerCase() == 'eventon') {
      if (finalSegment == 'concert') {
        finalLabel = 'Concert';
      }
    } else if (sourceRaw.toLowerCase() == 'wp_event_manager' || sourceRaw.toLowerCase() == 'wp-event-manager') {
      if (finalSegment == 'concert' || finalSegment == 'groupe-live') {
        finalSegment = 'groupe-live';
        finalLabel = 'Groupe Live';
      } else if (finalSegment == 'animation-dj' || finalSegment == 'dj') {
        finalSegment = 'animation';
        finalLabel = 'Animation';
      }
    }

    if (finalLabel.toLowerCase().contains('soir') && finalLabel.toLowerCase().contains('bar')) {
      finalLabel = 'Soirées et DJ';
    }

    return Event(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      link: json['link'] ?? '',
      description: json['description'] ?? '',
      dateStart: parsedDate,
      dateFormatted: json['date_formatted'] ?? '',
      locationAddress: location['address'] ?? 'Corse',
      lat: (location['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (location['lng'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image'] ?? '',
      segment: finalSegment,
      segmentLabel: finalLabel,
      source: sourceFriendly,
      distance: null,
    );
  }
}
