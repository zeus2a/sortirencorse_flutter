import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/network_item.dart';
import '../services/api_service.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<NetworkItem> _prestataires = [];
  List<NetworkItem> _venues = [];
  List<NetworkItem> _filteredItems = [];

  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _runSearch();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prestataires = await _apiService.fetchPrestataires();
      final venues = await _apiService.fetchVenues();

      if (mounted) {
        setState(() {
          _prestataires = prestataires;
          _venues = venues;
          _isLoading = false;
        });
        _runSearch();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _runSearch() {
    List<NetworkItem> currentList =
        _tabController.index == 0 ? _prestataires : _venues;

    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredItems = currentList;
      });
    } else {
      final query = _searchQuery.toLowerCase();
      setState(() {
        _filteredItems = currentList.where((item) {
          return item.title.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query) ||
              (item.categorie?.toLowerCase().contains(query) ?? false);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Safe area top + spacing
        SizedBox(height: MediaQuery.of(context).padding.top + 10),

        // Search Bar Glassmorphism
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                  onChanged: (val) {
                    _searchQuery = val;
                    _runSearch();
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher un partenaire, un lieu...',
                    hintStyle: GoogleFonts.outfit(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Custom Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.purpleAccent.withValues(alpha: 0.3),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle:
                  GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'Prestataires'),
                Tab(text: 'Lieux'),
              ],
            ),
          ),
        ),

        // List View
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _filteredItems.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                          top: 10, bottom: 120, left: 24, right: 24),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        return _buildNetworkCard(_filteredItems[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildNetworkCard(NetworkItem item) {
    final bool hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return GestureDetector(
        onTap: () => _showDetailsBottomSheet(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                children: [
                  // Image Thumbnail
                  if (hasImage)
                    Container(
                      width: 100,
                      height: 100,
                      color: Colors.black12,
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.05),
                          highlightColor: Colors.white.withValues(alpha: 0.15),
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.image_not_supported,
                            color: Colors.white24),
                      ),
                    )
                  else
                    Container(
                      width: 100,
                      height: 100,
                      color: Colors.white.withValues(alpha: 0.02),
                      child: Icon(
                        item.type == 'event_venue'
                            ? Icons.location_city_rounded
                            : Icons.handshake_rounded,
                        color: Colors.white24,
                        size: 40,
                      ),
                    ),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge catégorie
                          if (item.categorie != null &&
                              item.categorie!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color:
                                        Colors.orangeAccent.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                item.categorie!.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: Colors.orangeAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          Text(
                            item.title,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description.isNotEmpty
                                ? item.description
                                : 'Pas de présentation disponible.',
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.02),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            child: Row(
              children: [
                Container(width: 100, height: 100, color: Colors.white),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 16, width: 150, color: Colors.white),
                        const SizedBox(height: 10),
                        Container(
                            height: 10,
                            width: double.infinity,
                            color: Colors.white),
                        const SizedBox(height: 6),
                        Container(height: 10, width: 100, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Aucun résultat',
        style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
      ),
    );
  }

  void _showDetailsBottomSheet(NetworkItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool hasImage =
            item.imageUrl != null && item.imageUrl!.isNotEmpty;
        final double headerHeight =
            math.min(250.0, MediaQuery.of(context).size.height * 0.3);

        return DraggableScrollableSheet(
          initialChildSize: 0.95,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Header Image
                    if (hasImage)
                      Stack(
                        children: [
                          CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            width: double.infinity,
                            height: headerHeight,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.white10,
                              height: headerHeight,
                            ),
                          ),
                          Positioned(
                            top: 20,
                            right: 20,
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 30),
                              onPressed: () => Navigator.pop(context),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        height: 150,
                        color: Colors.white.withValues(alpha: 0.05),
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                item.type == 'event_venue'
                                    ? Icons.location_city_rounded
                                    : Icons.handshake_rounded,
                                color: Colors.white24,
                                size: 60,
                              ),
                            ),
                            Positioned(
                              top: 20,
                              right: 20,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 30),
                                onPressed: () => Navigator.pop(context),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.categorie != null &&
                              item.categorie!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        Colors.orangeAccent.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                item.categorie!.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: Colors.orangeAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          Text(
                            item.title,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          if (item.ville != null && item.ville!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white54, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.ville!,
                                    style: GoogleFonts.outfit(
                                        color: Colors.white54, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),

                          // Social Media Row (right after location)
                          if ((item.facebook != null &&
                                  item.facebook!.isNotEmpty) ||
                              (item.instagram != null &&
                                  item.instagram!.isNotEmpty) ||
                              (item.youtube != null &&
                                  item.youtube!.isNotEmpty) ||
                              (item.twitter != null &&
                                  item.twitter!.isNotEmpty) ||
                              (item.website != null &&
                                  item.website!.isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Row(
                                children: [
                                  if (item.facebook != null &&
                                      item.facebook!.isNotEmpty)
                                    _buildSocialIcon(
                                        FontAwesomeIcons.facebookF,
                                        item.facebook!,
                                        const Color(0xFF1877F2)),
                                  if (item.instagram != null &&
                                      item.instagram!.isNotEmpty)
                                    _buildSocialIcon(
                                        FontAwesomeIcons.instagram,
                                        item.instagram!,
                                        const Color(0xFFE4405F)),
                                  if (item.twitter != null &&
                                      item.twitter!.isNotEmpty)
                                    _buildSocialIcon(FontAwesomeIcons.twitter,
                                        item.twitter!, const Color(0xFF1DA1F2)),
                                  if (item.youtube != null &&
                                      item.youtube!.isNotEmpty)
                                    _buildSocialIcon(FontAwesomeIcons.youtube,
                                        item.youtube!, const Color(0xFFFF0000)),
                                  if (item.website != null &&
                                      item.website!.isNotEmpty)
                                    _buildSocialIcon(FontAwesomeIcons.globe,
                                        item.website!, Colors.white70),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),
                          Text(
                            "À propos",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.description.isNotEmpty
                                ? item.description
                                : 'Aucune description disponible pour ce profil.',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSocialIcon(FaIconData icon, String url, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: FaIcon(
              icon,
              color: color,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
