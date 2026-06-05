import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/event.dart';
import '../services/favorite_service.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // Favourite bounce animation
  late AnimationController _favController;
  late Animation<double> _favScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Bounce animation for favourite — overshoot like Instagram
    _favController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _favScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _favController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _favController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          height: math.min(380.0, MediaQuery.of(context).size.height * 0.45),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image with Hero
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Hero(
                  tag: 'event-image-${widget.event.id}',
                  child: CachedNetworkImage(
                    imageUrl: widget.event.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: isDark ? Colors.white10 : Colors.grey.shade200,
                      highlightColor:
                          isDark ? Colors.white24 : Colors.grey.shade100,
                      child: Container(
                          color: isDark ? Colors.black : Colors.white),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark
                          ? const Color(0xFF111111)
                          : const Color(0xFFF0F0F0),
                      child: Icon(
                        Icons.image_not_supported,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ),
                ),
              ),

              // Gradient Overlay for Text Readability
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),

              // Pastille Date (Couleur dynamique selon l'événement)
              Positioned(
                top: 20,
                left: 20,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9D4EDD),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.event.dateStart.day.toString(),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        Event.monthAbbr(widget.event.dateStart.month).toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        widget.event.dateStart.year.toString(),
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top Right Actions (Favorite)
              Positioned(
                top: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Favorite Heart Icon
                    ValueListenableBuilder<List<String>>(
                      valueListenable: FavoriteService.favoritesNotifier,
                      builder: (context, favorites, child) {
                        final isFav = favorites.contains(widget.event.id.toString());
                        return GestureDetector(
                          onTap: () async {
                            HapticFeedback.mediumImpact();
                            _favController.forward(from: 0.0);
                            await FavoriteService.toggleFavorite(widget.event.id.toString());
                          },
                          child: AnimatedBuilder(
                            animation: _favScale,
                            builder: (context, child) => Transform.scale(
                              scale: _favScale.value,
                              child: child,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isFav ? const Color(0xFFFF0000) : const Color(0xFFFF0000).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isFav ? const Color(0xFFFF0000) : const Color(0xFFFF0000).withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),              // Text Content (Bottom)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.event.title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: Color(0xFFFF6B6B), size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.event.cityName,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (widget.event.distance != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.near_me_rounded, color: Colors.blueAccent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.event.distanceLabel,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 5),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
