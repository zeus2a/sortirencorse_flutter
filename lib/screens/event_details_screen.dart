import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/event.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _contentAnimController;
  late Animation<double> _badgeFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _infoFade;
  late Animation<double> _descFade;

  @override
  void initState() {
    super.initState();

    _contentAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _contentAnimController,
          curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );

    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _contentAnimController,
          curve: const Interval(0.1, 0.5, curve: Curves.easeOutCubic)),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _contentAnimController,
          curve: const Interval(0.1, 0.5, curve: Curves.easeOut)),
    );

    _infoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _contentAnimController,
          curve: const Interval(0.3, 0.7, curve: Curves.easeOut)),
    );

    _descFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _contentAnimController,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    // Delay to let Hero animation settle first
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentAnimController.forward();
    });
  }

  @override
  void dispose() {
    _contentAnimController.dispose();
    super.dispose();
  }



  Future<void> _openMap(String address, double lat, double lng) async {
    if (lat == 0.0 && lng == 0.0) {
      final encodedAddress = Uri.encodeComponent(address);
      final googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encodedAddress";
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      }
      return;
    }

    try {
      final availableMaps = await MapLauncher.installedMaps;
      if (availableMaps.isEmpty) {
        final googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
        if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
          await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
        }
        return;
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Wrap(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Ouvrir avec...',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    for (var map in availableMaps)
                      ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          map.showMarker(
                            coords: Coords(lat, lng),
                            title: widget.event.title,
                            description: address,
                          );
                        },
                        title: Text(
                          map.mapName,
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        leading: SvgPicture.asset(
                          map.icon,
                          height: 30.0,
                          width: 30.0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error launching map: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF050505) : const Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Image avec Hero animation et bouton retour glassmorphism
          SliverAppBar(
            expandedHeight: 420.0,
            pinned: true,
            backgroundColor: bgColor,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                      onPressed: () {
                        // HapticFeedback removed for speed
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'event-image-${widget.event.id}',
                    child: CachedNetworkImage(
                      imageUrl: widget.event.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Premium gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          bgColor.withValues(alpha: 0.3),
                          bgColor.withValues(alpha: 0.8),
                          bgColor,
                        ],
                        stops: const [0.0, 0.4, 0.6, 0.8, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenu des détails avec animations staggered
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _contentAnimController,
              builder: (context, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge et Source
                      FadeTransition(
                        opacity: _badgeFade,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: widget.event.segment == 'party'
                                    ? Colors.purple
                                    : Colors.amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.event.segmentLabel.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Source: ${widget.event.source.toUpperCase()}",
                              style: GoogleFonts.outfit(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Titre animé
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Text(
                            widget.event.title,
                            style: GoogleFonts.outfit(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Info Cards glassmorphism
                      FadeTransition(
                        opacity: _infoFade,
                        child: Column(
                          children: [
                            _buildInfoCard(
                              icon: Icons.calendar_today_rounded,
                              text: '${widget.event.dateFormatted} ${widget.event.dateStart.year} à ${widget.event.dateStart.hour}h${widget.event.dateStart.minute.toString().padLeft(2, '0')}',
                              color: Colors.blueAccent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                            _buildInfoCard(
                              icon: Icons.location_on_rounded,
                              text: widget.event.locationAddress,
                              color: Colors.redAccent,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                      FadeTransition(
                        opacity: _descFade,
                        child: Divider(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Description
                      FadeTransition(
                        opacity: _descFade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "À propos",
                              style: GoogleFonts.outfit(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A2E),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.event.description,
                              style: GoogleFonts.outfit(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                          height: 120), // Espace pour les boutons du bas
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // Boutons d'action flottants en bas
      bottomSheet: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(
                  color:
                      isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                // Itinéraire button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // HapticFeedback removed for speed
                      _openMap(widget.event.locationAddress, widget.event.lat,
                          widget.event.lng);
                    },
                    icon: const Icon(Icons.directions_rounded,
                        color: Colors.white, size: 20),
                    label: Text(
                      "ITINÉRAIRE",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Partager button
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // HapticFeedback removed for speed
                      Share.share(
                        '🎉 ${widget.event.title}\n📅 ${widget.event.dateFormatted}\n📍 ${widget.event.locationAddress}\n\nDécouvre cet événement sur Sortir en Corse !',
                      );
                    },
                    icon: Icon(
                      Icons.share_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 22,
                    ),
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String text,
    required Color color,
    required bool isDark,
    bool hasArrow = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (hasArrow)
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isDark ? Colors.white24 : Colors.black26,
              size: 14,
            ),
        ],
      ),
    );
  }
}
