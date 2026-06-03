import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/favorite_service.dart';
import '../services/api_service.dart';
import '../models/event.dart';
import '../widgets/event_card.dart';
import 'event_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Event> _allEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
                  padding: const EdgeInsets.only(top: 10, bottom: 120),
                  itemCount: favoriteEvents.length,
                  itemBuilder: (context, index) {
                    final event = favoriteEvents[index];
                    return EventCard(
                      event: event,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 400),
                            reverseTransitionDuration:
                                const Duration(milliseconds: 350),
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    EventDetailsScreen(event: event),
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
                              return FadeTransition(
                                  opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
