import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
/// Premium glassmorphism drawer with À Propos, Contact, Share, etc.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = 'v${info.version}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth * 0.78,
      child: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0A0A).withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.95),
                border: Border(
                  right: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header with logo ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF9E00)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    'assets/icon.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF1A1A2E),
                                      child: const Icon(Icons.explore_rounded,
                                          color: Color(0xFFFF9E00), size: 28),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sortir en Corse',
                                      style: GoogleFonts.outfit(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A2E),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _version,
                                      style: GoogleFonts.outfit(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9E00).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      const Color(0xFFFF9E00).withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              '🌴 Votre guide événementiel en Corse',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFF9E00),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Divider(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                      indent: 24,
                      endIndent: 24,
                    ),
                    const SizedBox(height: 8),

                    // ── Menu Items ──
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildSectionLabel('DÉCOUVRIR', isDark),
                          _buildMenuItem(
                            icon: Icons.info_rounded,
                            label: 'À propos',
                            color: Colors.blueAccent,
                            isDark: isDark,
                            onTap: () => _showAboutSheet(context, isDark),
                          ),
                          _buildMenuItem(
                            icon: Icons.email_rounded,
                            label: 'Nous contacter',
                            color: Colors.greenAccent,
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              _showContactSheet(context, isDark);
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('COMMUNAUTÉ', isDark),
                          _buildMenuItem(
                            icon: Icons.share_rounded,
                            label: 'Partager l\'app',
                            color: Colors.purpleAccent,
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              Share.share(
                                '🌴 Découvre Sortir en Corse !\n\nL\'app pour ne rien rater des événements en Corse 🎉\n\nhttps://play.google.com/store/apps/details?id=com.zeus2a.sortirencorse',
                              );
                            },
                          ),
                          
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),

                    // ── Footer ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Column(
                        children: [
                          Divider(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Made with ❤️ in Corsica',
                            style: GoogleFonts.outfit(
                              color: isDark ? Colors.white24 : Colors.black26,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '© ${DateTime.now().year} Corse Music Events',
                            style: GoogleFonts.outfit(
                              color: isDark ? Colors.white10 : Colors.black12,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: isDark ? Colors.white30 : Colors.black26,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        onTap: () {
          onTap();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(icon, color: color, size: 20),
          ),
        ),
        title: Text(
          label,
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              )
            : null,
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: isDark ? Colors.white12 : Colors.black26,
          size: 14,
        ),
      ),
    );
  }

  // ── Contact Bottom Sheet with Tabs ──
  void _showContactSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _ContactSheet(isDark: isDark);
      },
    );
  }

  // ── About Bottom Sheet ──
  void _showAboutSheet(BuildContext context, bool isDark) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'À propos',
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sortir en Corse est l\'application de référence pour découvrir tous les événements de l\'île de beauté.',
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Concerts, festivals, spectacles, expositions, soirées… retrouvez en un coup d\'œil tout ce qui se passe près de chez vous.',
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9E00).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.code_rounded,
                              color: Color(0xFFFF9E00), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Développé par',
                                style: GoogleFonts.outfit(
                                  color:
                                      isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'Corse Music Events',
                                style: GoogleFonts.outfit(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tabbed Contact Sheet — 3 categories like CantiCorsi
class _ContactSheet extends StatefulWidget {
  final bool isDark;
  const _ContactSheet({required this.isDark});

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();

  final _tabs = const [
    Tab(
      icon: Icon(Icons.event_rounded, size: 20),
      text: 'Événement',
    ),
    Tab(
      icon: Icon(Icons.report_problem_rounded, size: 20),
      text: 'Problème',
    ),
    Tab(
      icon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
      text: 'Autre',
    ),
  ];

  final _subjects = [
    'Proposer un événement',
    'Signaler un problème',
    'Autre demande',
  ];

  final _hints = [
    'Décrivez l\'événement que vous souhaitez proposer (nom, lieu, date, description)...',
    'Décrivez le problème rencontré (écran, action, message d\'erreur)...',
    'Votre message...',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _messageController.clear();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendEmail() async {
    final subject = 'Sortir en Corse - ${_subjects[_tabController.index]}';
    final body = _messageController.text.trim();

    if (body.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF9E00))),
    );

    try {
      final response = await http.post(
        Uri.parse('https://api.corsemusicevents.fr/contact.php'),
        body: {
          'subject': subject,
          'message': body,
        },
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close sheet
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200 ? 'Message envoyé avec succès !' : 'Erreur lors de l\'envoi.',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: response.statusCode == 200 ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion.', style: GoogleFonts.outfit()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Nous contacter',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelStyle: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w400),
                  labelColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  unselectedLabelColor:
                      isDark ? Colors.white38 : Colors.black38,
                  indicator: BoxDecoration(
                    color: const Color(0xFFFF9E00).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFF9E00).withValues(alpha: 0.4)),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: _tabs,
                ),
              ),

              const SizedBox(height: 20),

              // Message field
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: _hints[_tabController.index],
                        hintStyle: GoogleFonts.outfit(
                          color: isDark ? Colors.white24 : Colors.black26,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Send button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      'Envoyer',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9E00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

