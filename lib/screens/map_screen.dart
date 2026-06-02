import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_rounded, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 20),
          Text(
            'Carte Interactive',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Bientôt disponible',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
