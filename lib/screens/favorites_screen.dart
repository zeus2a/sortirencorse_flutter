import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import '../services/favorite_service.dart';
import '../services/api_service.dart';
import '../models/event.dart';
import 'event_details_screen.dart';
import 'settings_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Event> _allEvents = [];
  bool _isLoading = true;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userPosition = position;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await ApiService().fetchEvents();
      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static String _monthAbbr(int month) {
    const months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return months[month];
  }

  void _openEventDetail(Event event) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            EventDetailsScreen(event: event),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Vos Favoris',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF9E00)))
          : ValueListenableBuilder<List<String>>(
              valueListenable: FavoriteService.favoritesNotifier,
              builder: (context, favoriteIds, child) {
                final favoriteEvents = _allEvents
                    .where((e) => favoriteIds.contains(e.id.toString()))
                    .map((e) {
                      if (_userPosition != null && SettingsScreen.isGpsEnabled) {
                        double distanceInMeters = Geolocator.distanceBetween(
                            _userPosition!.latitude, _userPosition!.longitude,
                            e.lat, e.lng);
                        return e.copyWith(distance: distanceInMeters / 1000);
                      }
                      return e;
                    })
                    .toList();

                if (favoriteEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.heart_broken_rounded,
                            size: 80,
                            color: isDark ? Colors.white24 : Colors.black12),
                        const SizedBox(height: 20),
                        Text(
                          'Aucun favori',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Vos événements préférés apparaîtront ici.',
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 10, bottom: 120, left: 24, right: 24),
                  itemCount: favoriteEvents.length,
                  itemBuilder: (context, index) {
                    final event = favoriteEvents[index];
                    final catStyle = Event.getCategoryStyle(event.segmentLabel);

                    return GestureDetector(
                      onTap: () => _openEventDetail(event),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Row(
                            children: [
                              // Image thumbnail
                              SizedBox(
                                width: 100,
                                height: 110,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: event.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Shimmer.fromColors(
                                        baseColor: isDark
                                            ? Colors.white10
                                            : Colors.grey.shade200,
                                        highlightColor: isDark
                                            ? Colors.white24
                                            : Colors.grey.shade100,
                                        child: Container(
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : Colors.grey.shade100,
                                        child: Icon(
                                            Icons.image_not_supported_rounded,
                                            color: isDark
                                                ? Colors.white24
                                                : Colors.black26),
                                      ),
                                    ),
                                    // Date overlay
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9D4EDD),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${event.dateStart.day} ${_monthAbbr(event.dateStart.month)} ${event.dateStart.year}',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Content
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 14.0, right: 8.0, top: 10.0, bottom: 14.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Type badge
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (catStyle['color'] as Color)
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color:
                                                  (catStyle['color'] as Color)
                                                      .withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          event.segmentLabel.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            color:
                                                catStyle['color'] as Color,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                      // Title
                                      Text(
                                        event.title,
                                        style: GoogleFonts.outfit(
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1A2E),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // Date
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_month_rounded,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                              size: 14),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${event.dateFormatted} ${event.dateStart.year}',
                                              style: GoogleFonts.outfit(
                                                color: isDark ? Colors.white54 : Colors.black45,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Time
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                              size: 14),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'À ${event.dateStart.hour}h${event.dateStart.minute.toString().padLeft(2, '0')}',
                                              style: GoogleFonts.outfit(
                                                color: isDark ? Colors.white54 : Colors.black45,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // City
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded,
                                              color: isDark ? Colors.white38 : Colors.black38,
                                              size: 14),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              event.cityName,
                                              style: GoogleFonts.outfit(
                                                color: isDark ? Colors.white54 : Colors.black45,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (event.distance != null) ...[
                                        const SizedBox(height: 4),
                                        // Distance
                                        Row(
                                          children: [
                                            const Icon(Icons.near_me_rounded,
                                                color: Colors.blueAccent,
                                                size: 14),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                event.distance! < 1.0 
                                                    ? 'À ${(event.distance! * 1000).toInt()} m de vous' 
                                                    : 'À ${event.distance!.toStringAsFixed(1)} km de vous',
                                                style: GoogleFonts.outfit(
                                                  color: isDark ? Colors.white54 : Colors.black45,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // Favorite button
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () async {
                                    await FavoriteService.toggleFavorite(
                                        event.id.toString());
                                  },
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
