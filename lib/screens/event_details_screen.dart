import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import '../models/event.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  Future<void> _openMap(BuildContext context, String address, double lat, double lng) async {
    String googleMapsUrl;
    String appleMapsUrl;
    
    String wazeUrl;
    
    if (lat == 0.0 && lng == 0.0) {
      final encodedAddress = Uri.encodeComponent(address);
      googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$encodedAddress";
      appleMapsUrl = "https://maps.apple.com/?q=$encodedAddress";
      wazeUrl = "https://waze.com/ul?q=$encodedAddress&navigate=yes";
    } else {
      googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      appleMapsUrl = "https://maps.apple.com/?q=$lat,$lng";
      wazeUrl = "https://waze.com/ul?ll=$lat,$lng&navigate=yes";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "Ouvrir avec",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (Theme.of(context).platform == TargetPlatform.iOS)
                ListTile(
                  leading: const Icon(Icons.map, color: Colors.blueAccent),
                  title: Text('Plans (Apple Maps)', style: GoogleFonts.outfit(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
                      await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.location_on, color: Colors.redAccent),
                title: Text('Google Maps', style: GoogleFonts.outfit(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
                    await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.navigation, color: Colors.cyan),
                title: Text('Waze', style: GoogleFonts.outfit(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  if (await canLaunchUrl(Uri.parse(wazeUrl))) {
                    await launchUrl(Uri.parse(wazeUrl), mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: CustomScrollView(
        slivers: [
          // Image avec Hero animation et bouton retour
          SliverAppBar(
            expandedHeight: 400.0,
            pinned: true,
            backgroundColor: const Color(0xFF020617),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'event-image-${event.id}',
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          
          // Contenu des détails
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge et Source
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: event.segment == 'party' ? Colors.purple : Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          event.segmentLabel.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Source: ${event.source.toUpperCase()}",
                        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Titre
                  Text(
                    event.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Infos Date et Lieu
                  _buildInfoRow(Icons.calendar_today, event.dateFormatted, Colors.blueAccent),
                  const SizedBox(height: 12),
                  _buildInfoRow(Icons.location_on, event.locationAddress, Colors.redAccent),
                  
                  const SizedBox(height: 30),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 30),
                  
                  // Description
                  Text(
                    "À propos",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.description,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  
                  if (event.lat != 0.0 && event.lng != 0.0) ...[
                    const SizedBox(height: 30),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 30),
                    Text(
                      "Localisation",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: latlong2.LatLng(event.lat, event.lng),
                            initialZoom: 15.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none, // Bloque le zoom/scroll pour l'UX
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.zeus2a.sortirencorse',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: latlong2.LatLng(event.lat, event.lng),
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF9E00),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF9E00).withValues(alpha: 0.6),
                                          blurRadius: 16,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 100), // Espace pour le bouton du bas
                ],
              ),
            ),
          ),
        ],
      ),
      
      // Boutons d'action flottants en bas
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openMap(context, event.locationAddress, event.lat, event.lng),
                icon: const Icon(Icons.directions, color: Colors.white, size: 18),
                label: Text("ITINÉRAIRE", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
