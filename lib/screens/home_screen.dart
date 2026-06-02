import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/event_card.dart';
import '../utils/search_engine.dart';
import 'event_details_screen.dart';
import 'map_screen.dart';
import 'network_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import '../services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  
  List<Event> _allEvents = [];
  List<Event> _filteredEvents = [];
  bool _isLoading = true;
  bool _hasError = false;
  
  String _searchQuery = '';
  Timer? _debounce;
  
  Position? _userPosition;
  bool _showLocationToast = false;
  
  int _currentIndex = 0;

  int _displayLimit = 25;
  
  bool _hasUpdate = false;
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _refreshEvents();
    _checkLocationPermission();
    _checkAppUpdate();
  }

  Future<void> _checkAppUpdate() async {
    final serverInfo = await UpdateService.checkForUpdates();
    if (serverInfo != null) {
      final isUpdateAvailable = await UpdateService.isUpdateAvailable(serverInfo);
      if (isUpdateAvailable && mounted) {
        setState(() {
          _hasUpdate = true;
          _updateInfo = serverInfo;
        });
        if (serverInfo.forceUpdate) {
          _showForceUpdateDialog();
        }
      }
    }
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.system_update_rounded, color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(child: Text('Mise à jour requise', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Text(
              _updateInfo?.message ?? 'Cette version de l\'application n\'est plus supportée. Veuillez la mettre à jour.',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  final url = Theme.of(context).platform == TargetPlatform.iOS 
                      ? _updateInfo?.appStoreUrl 
                      : _updateInfo?.playStoreUrl;
                  if (url != null && url.isNotEmpty) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: Text('Mettre à jour', style: GoogleFonts.outfit(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _showLocationToast = true);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      setState(() => _showLocationToast = true);
      return;
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    } 

    _getUserLocation();
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission currentPermission = await Geolocator.checkPermission();
    
    // CORRECTION iOS/iPhone: Si refusé définitivement, requestPermission() ne fait rien.
    // Il faut obligatoirement ouvrir les paramètres de l'application.
    if (currentPermission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    LocationPermission permission = await Geolocator.requestPermission();
    
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      setState(() => _showLocationToast = false);
      _getUserLocation();
    } else if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _userPosition = position;
      });
      _runSmartSearch(); // Re-sort with distance
    } catch (e) {
      // Handle error implicitly
    }
  }

  Future<void> _refreshEvents() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _displayLimit = 25; // Reset limit on refresh
    });
    
    // 1. Chargement depuis le cache local (Instantané)
    try {
      final cachedEvents = await _apiService.getCachedEvents();
      if (cachedEvents.isNotEmpty) {
        if (mounted) {
          setState(() {
            _allEvents = cachedEvents;
            _isLoading = false;
          });
          _runSmartSearch();
        }
      }
    } catch (e) {
      debugPrint('Erreur lecture cache');
    }

    // 2. Chargement depuis le serveur (Arrière-plan)
    try {
      final events = await _apiService.fetchEvents();
      if (mounted) {
        setState(() {
          _allEvents = events;
          _isLoading = false;
          _hasError = false;
        });
        _runSmartSearch();
      }
    } catch (e) {
      if (mounted && _allEvents.isEmpty) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
      });
      _runSmartSearch();
    });
  }

  Future<void> _runSmartSearch() async {
    if (_allEvents.isEmpty) return;
    
    final results = await SmartSearch.processEvents(
      allEvents: _allEvents,
      query: _searchQuery,
      userPosition: SettingsScreen.isGpsEnabled ? _userPosition : null,
    );
    
    setState(() {
      _filteredEvents = results;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour,';
    if (hour < 18) return 'Bon après-midi,';
    return 'Bonsoir,';
  }

  String _getSubGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Une belle journée s\'annonce.';
    if (hour < 18) return 'Envie de sortir ?';
    return 'Prêt pour ce soir ?';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    
    return '📅 $dayName ${now.day} $monthName';
  }

  @override
  Widget build(BuildContext context) {
    bool isGpsActive = _userPosition != null && SettingsScreen.isGpsEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Apple Dark Mode Black
      body: Stack(
        children: [
          // Ambient Background Blobs
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Main Content with IndexedStack
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildFeedTab(isGpsActive),
              const MapScreen(),
              const NetworkScreen(),
              const FavoritesScreen(),
            ],
          ),

          // Bottom Navigation Bar Glassmorphism
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, Icons.explore_rounded, 'Découvrir'),
                      _buildNavItem(1, Icons.map_rounded, 'Carte'),
                      _buildNavItem(2, Icons.handshake_rounded, 'Réseau'),
                      _buildNavItem(3, Icons.bookmark_rounded, 'Favoris'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Smart Location Toast (Mode 2026 UX)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutExpo,
            bottom: _showLocationToast && _currentIndex == 0 ? 120 : -100,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.blueAccent, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Activez la localisation pour voir les événements juste à côté de vous.",
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _requestLocationPermission,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("Activer", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedTab(bool isGpsActive) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 230.0,
          floating: true,
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Brand / Logo Capsule on the left, Date Capsule on the right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Brand / Logo Capsule
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/icon.png',
                                  width: 14,
                                  height: 14,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.explore_rounded, 
                                    color: Colors.blueAccent, 
                                    size: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Sortir en Corse',
                                style: GoogleFonts.philosopher(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Date Capsule (Exact same styling as the old date container)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            _getFormattedDate(),
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Row containing: Greeting on the left, GPS & Settings on the right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getGreeting(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isGpsActive 
                                    ? Colors.greenAccent.withValues(alpha: 0.2)
                                    : Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isGpsActive 
                                      ? Colors.greenAccent.withValues(alpha: 0.5)
                                      : Colors.redAccent.withValues(alpha: 0.5)
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isGpsActive ? Icons.my_location_rounded : Icons.location_off_rounded, 
                                    color: isGpsActive ? Colors.greenAccent : Colors.redAccent, 
                                    size: 14
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isGpsActive ? 'GPS Actif' : 'GPS Inactif', 
                                    style: GoogleFonts.outfit(
                                      color: isGpsActive ? Colors.greenAccent : Colors.redAccent, 
                                      fontSize: 10, 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Badge(
                                isLabelVisible: _hasUpdate,
                                backgroundColor: Colors.redAccent,
                                child: const Icon(Icons.settings_rounded, color: Colors.white70, size: 28),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                                ).then((_) => _checkLocationPermission());
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Sub-greeting "Prêt pour ce soir ?"
                    Text(
                      _getSubGreeting(),
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    
                    // Event counter (Orange badge)
                    if (!_isLoading && _allEvents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${_allEvents.length} événements à venir', 
                                style: GoogleFonts.outfit(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                    const Spacer(),
                    
                    // Search Bar Glassmorphism (Omnibox)
                    ClipRRect(
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
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Rechercher un artiste, un lieu, une ville...',
                              hintStyle: GoogleFonts.outfit(color: Colors.white38),
                              prefixIcon: const Icon(Icons.search, color: Colors.white54),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        ..._buildSliverBody(),
      ],
    );
  }

  List<Widget> _buildSliverBody() {
    if (_isLoading) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 30, bottom: 10, left: 24, right: 24),
            child: Column(
              children: [
                Text(
                  "Première synchronisation en cours...",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.orangeAccent.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Nous téléchargeons le catalogue complet pour vous garantir une navigation instantanée par la suite.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  height: 380,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: const Color(0xFF0A0A0A),
                  ),
                  child: Shimmer.fromColors(
                    baseColor: Colors.white.withValues(alpha: 0.05),
                    highlightColor: Colors.white.withValues(alpha: 0.15),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
              childCount: 3,
            ),
          ),
        ),
      ];
    }
    
    if (_hasError) {
      return [SliverToBoxAdapter(child: _buildErrorState())];
    }
    
    if (_filteredEvents.isEmpty) {
      return [SliverToBoxAdapter(child: _buildEmptyState(isSearch: _searchQuery.isNotEmpty))];
    }

    final int itemCount = _filteredEvents.length > _displayLimit ? _displayLimit : _filteredEvents.length;
    final bool showLoadMore = _filteredEvents.length > _displayLimit;

    return [
      SliverPadding(
        padding: const EdgeInsets.only(top: 10),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return EventCard(
                event: _filteredEvents[index],
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 400),
                      pageBuilder: (context, animation, secondaryAnimation) => 
                          EventDetailsScreen(event: _filteredEvents[index]),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
              );
            },
            childCount: itemCount,
          ),
        ),
      ),
      if (showLoadMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120.0, top: 20.0),
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() {
                    _displayLimit += 25;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Afficher plus d'événements", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        )
      else
        const SliverToBoxAdapter(
          child: SizedBox(height: 120), // Padding for BottomBar
        ),
    ];
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white38, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            Text('Connexion perdue', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _refreshEvents,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text('Réessayer', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isSearch = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Text(
          isSearch ? 'Aucun résultat trouvé' : 'Aucun événement',
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16),
        ),
      ),
    );
  }
}
