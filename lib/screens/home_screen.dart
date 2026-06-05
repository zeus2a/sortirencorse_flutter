import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
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
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Event> _allEvents = [];
  List<Event> _filteredEvents = [];
  bool _isLoading = true;
  bool _hasError = false;

  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  Timer? _debounce;

  Position? _userPosition;
  bool _showLocationToast = false;

  int _currentIndex = 0;

  int _displayLimit = 50;

  bool _hasUpdate = false;
  UpdateInfo? _updateInfo;

  // ── Animation Controllers ──
  late AnimationController _headerAnimController;
  late AnimationController _navGlowController;

  // Staggered header animations
  late Animation<double> _brandFade;
  late Animation<Offset> _brandSlide;
  late Animation<double> _greetingFade;
  late Animation<Offset> _greetingSlide;
  late Animation<double> _searchFade;
  late Animation<Offset> _searchSlide;

  @override
  void initState() {
    super.initState();

    // Header staggered animation setup
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _brandFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _headerAnimController,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _brandSlide =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _headerAnimController,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic)),
    );

    _greetingFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _headerAnimController,
          curve: const Interval(0.2, 0.6, curve: Curves.easeOut)),
    );
    _greetingSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _headerAnimController,
          curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic)),
    );

    _searchFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _headerAnimController,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );
    _searchSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _headerAnimController,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)),
    );

    // Nav glow pulsing animation
    _navGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Start header animation
    _headerAnimController.forward();

    _refreshEvents();
    _checkLocationPermission();
    _checkAppUpdate();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _navGlowController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkAppUpdate() async {
    final serverInfo = await UpdateService.checkForUpdates();
    if (serverInfo != null) {
      final isUpdateAvailable =
          await UpdateService.isUpdateAvailable(serverInfo);
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.system_update_rounded,
                    color: Colors.redAccent),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Mise à jour requise',
                        style: GoogleFonts.outfit(
                            color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Text(
              _updateInfo?.message ??
                  'Cette version de l\'application n\'est plus supportée. Veuillez la mettre à jour.',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  final url = Theme.of(context).platform == TargetPlatform.iOS
                      ? _updateInfo?.appStoreUrl
                      : _updateInfo?.playStoreUrl;
                  if (url != null && url.isNotEmpty) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: Text('Mettre à jour',
                    style: GoogleFonts.outfit(color: Colors.white)),
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

    if (currentPermission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
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
        // Global distance calculation for Map and Favorites
        if (SettingsScreen.isGpsEnabled) {
          _allEvents = _allEvents.map((e) {
            if (e.lat != 0.0 && e.lng != 0.0) {
              final d = Geolocator.distanceBetween(
                  position.latitude, position.longitude, e.lat, e.lng);
              return e.copyWith(distance: d / 1000);
            }
            return e;
          }).toList();
        }
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
      _displayLimit = 50; // Reset limit on refresh
    });

    // 1. Chargement depuis le cache local (Instantané)
    try {
      final cachedEvents = await _apiService.getCachedEvents();
      if (cachedEvents.isNotEmpty) {
        if (mounted) {
          setState(() {
            _allEvents = cachedEvents;
            _isLoading = false;

            // Global distance calculation for Map and Favorites
            if (_userPosition != null && SettingsScreen.isGpsEnabled) {
              _allEvents = _allEvents.map((e) {
                if (e.lat != 0.0 && e.lng != 0.0) {
                  final d = Geolocator.distanceBetween(
                      _userPosition!.latitude, _userPosition!.longitude, e.lat, e.lng);
                  return e.copyWith(distance: d / 1000);
                }
                return e;
              }).toList();
            }
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

    var results = await SmartSearch.processEvents(
      allEvents: _allEvents,
      query: _searchQuery,
      userPosition: SettingsScreen.isGpsEnabled ? _userPosition : null,
    );

    if (_selectedDateRange != null) {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end.add(const Duration(days: 1));
      results = results.where((e) {
        return e.dateStart
                .isAfter(start.subtract(const Duration(seconds: 1))) &&
            e.dateStart.isBefore(end);
      }).toList();
    } else {
      final start = DateTime.now().subtract(const Duration(days: 1));
      final end = DateTime.now().add(const Duration(days: 60));
      results = results.where((e) {
        return e.dateStart
                .isAfter(start.subtract(const Duration(seconds: 1))) &&
            e.dateStart.isBefore(end);
      }).toList();
    }

    setState(() {
      _filteredEvents = results;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 19) return 'Bonjour,';
    return 'Bonsoir,';
  }

  String _getSubGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 19) return 'Une belle journée s\'annonce !';
    return 'Une belle soirée s\'annonce !';
  }

  String _getFormattedDate() {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre'
    ];

    if (_selectedDateRange != null) {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end;

      final startStr = '${start.day} ${months[start.month - 1]} ${start.year}';
      final endStr = '${end.day} ${months[end.month - 1]} ${end.year}';

      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        return '$startStr (Filtre)';
      }
      if (start.year == end.year) {
        final shortStartStr = '${start.day} ${months[start.month - 1]}';
        return 'Du $shortStartStr au $endStr';
      }
      return 'Du $startStr au $endStr';
    }

    final now = DateTime.now();
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];

    return '$dayName ${now.day} $monthName ${now.year}';
  }

  void _showCalendarPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final initialDate = DateTime(now.year, now.month, now.day);

    List<DateTime?> tempValues = [];
    if (_selectedDateRange != null) {
      tempValues = [_selectedDateRange!.start, _selectedDateRange!.end];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Période de sortie',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sélectionnez une date de début et de fin',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CalendarDatePicker2(
                      config: CalendarDatePicker2Config(
                        calendarType: CalendarDatePicker2Type.range,
                        firstDate: initialDate,
                        lastDate: DateTime(now.year + 2),
                        selectedDayHighlightColor: const Color(0xFFFF9E00),
                        selectedRangeHighlightColor:
                            const Color(0xFFFF9E00).withValues(alpha: 0.15),
                        weekdayLabelTextStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        controlsTextStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        dayTextStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        disabledDayTextStyle: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                      value: tempValues,
                      onValueChanged: (dates) {
                        setModalState(() {
                          tempValues = dates;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: tempValues.isNotEmpty
                            ? () {
                                setState(() {
                                  if (tempValues.length == 1) {
                                    _selectedDateRange = DateTimeRange(
                                        start: tempValues[0]!,
                                        end: tempValues[0]!);
                                  } else if (tempValues.length >= 2) {
                                    _selectedDateRange = DateTimeRange(
                                        start: tempValues[0]!,
                                        end: tempValues[1] ?? tempValues[0]!);
                                  }
                                });
                                _runSmartSearch();
                                Navigator.pop(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9E00),
                          disabledBackgroundColor:
                              isDark ? Colors.white12 : Colors.black12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: tempValues.isNotEmpty ? 4 : 0,
                        ),
                        child: Text(
                          '✔ VALIDER MA PÉRIODE',
                          style: GoogleFonts.outfit(
                            color: tempValues.isNotEmpty
                                ? Colors.white
                                : (isDark ? Colors.white38 : Colors.black38),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isGpsActive = _userPosition != null && SettingsScreen.isGpsEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor:
          isDark ? const Color(0xFF000000) : const Color(0xFFF8F9FA),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          

          // Main Content with IndexedStack
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildFeedTab(isGpsActive, isDark),
              MapScreen(initialEvents: _allEvents, initialPosition: _userPosition),
              const NetworkScreen(),
              FavoritesScreen(allEvents: _allEvents),
            ],
          ),

          // Bottom Navigation Bar Glassmorphism
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + (Platform.isIOS ? 8 : 20),
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: AnimatedBuilder(
                  animation: _navGlowController,
                  builder: (context, child) {
                    return Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(
                          0, Icons.explore_rounded, 'Découvrir', isDark),
                      _buildNavItem(1, Icons.map_rounded, 'Carte', isDark),
                      _buildNavItem(
                          2, Icons.handshake_rounded, 'Réseau', isDark),
                      _buildNavItem(
                          3, Icons.bookmark_rounded, 'Favoris', isDark),
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
            bottom: _showLocationToast && _currentIndex == 0
                ? MediaQuery.of(context).padding.bottom + (Platform.isIOS ? 98 : 110)
                : -100,
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
                    border:
                        Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: Colors.blueAccent, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Activer le GPS pour géolocaliser les événements autour de vous ?",
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showLocationToast = false;
                          });
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("Non",
                            style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _requestLocationPermission,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("Oui",
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
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

  Widget _buildFeedTab(bool isGpsActive, bool isDark) {
    return RefreshIndicator(
      onRefresh: _refreshEvents,
      color: const Color(0xFFFF9E00),
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          SliverAppBar(
            expandedHeight: 255.0,
            floating: true,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle:
                isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
              fit: StackFit.expand,
              children: [
                // Hero Background Image
                Image.asset(
                  'assets/ajaccio_lasers.png',
                  fit: BoxFit.cover,
                ),
                // Gradient Overlay for readability - Plus transparent pour voir l'image
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        isDark ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.1),
                        isDark ? const Color(0xFF000000).withValues(alpha: 0.9) : const Color(0xFFF8F9FA).withValues(alpha: 0.9),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
                SafeArea(
                child: AnimatedBuilder(
                  animation: _headerAnimController,
                  builder: (context, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Menu Hamburger | Date | Settings
                          SlideTransition(
                            position: _brandSlide,
                            child: FadeTransition(
                              opacity: _brandFade,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Hamburger menu button
                                  GestureDetector(
                                    onTap: () {
                                      // HapticFeedback removed for speed
                                      _scaffoldKey.currentState?.openDrawer();
                                    },
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(alpha: 0.6)
                                            : Colors.white.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.2)
                                              : Colors.black.withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.menu_rounded,
                                        color: isDark ? Colors.white : Colors.black87,
                                        size: 24,
                                      ),
                                    ),
                                  ),

                                  // Date capsule (center)
                                  GestureDetector(
                                    onTap: () {
                                      if (_selectedDateRange != null) {
                                        setState(() {
                                          _selectedDateRange = null;
                                        });
                                        _runSmartSearch();
                                      } else {
                                        _showCalendarPicker();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(alpha: 0.6)
                                            : Colors.white.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.2)
                                              : Colors.black.withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4, horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: _selectedDateRange != null
                                              ? Colors.greenAccent
                                                  .withValues(alpha: 0.15)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_month_rounded,
                                              color: _selectedDateRange != null
                                                  ? Colors.greenAccent
                                                  : const Color(0xFF9D4EDD),
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _getFormattedDate(),
                                              style: GoogleFonts.outfit(
                                                color: _selectedDateRange != null
                                                    ? Colors.greenAccent
                                                    : (isDark ? Colors.white : Colors.black87),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (_selectedDateRange != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.greenAccent
                                                      .withValues(alpha: 0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                    Icons.close_rounded,
                                                    size: 16,
                                                    color: Colors.greenAccent),
                                              )
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Settings icon
                                  GestureDetector(
                                    onTap: () {
                                      // HapticFeedback removed for speed
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          transitionDuration:
                                              const Duration(milliseconds: 350),
                                          reverseTransitionDuration:
                                              const Duration(milliseconds: 300),
                                          pageBuilder: (context, animation,
                                                  secondaryAnimation) =>
                                              const SettingsScreen(),
                                          transitionsBuilder: (context,
                                              animation,
                                              secondaryAnimation,
                                              child) {
                                            return SlideTransition(
                                              position: Tween<Offset>(
                                                begin: const Offset(1.0, 0.0),
                                                end: Offset.zero,
                                              ).animate(CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.easeOutCubic,
                                              )),
                                              child: child,
                                            );
                                          },
                                        ),
                                      ).then((_) => _checkLocationPermission());
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(alpha: 0.6)
                                            : Colors.white.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.2)
                                              : Colors.black.withValues(alpha: 0.1),
                                        ),
                                      ),
                                      child: Badge(
                                        isLabelVisible: _hasUpdate,
                                        backgroundColor: Colors.redAccent,
                                        child: Icon(
                                          Icons.settings_rounded,
                                          color: isDark ? Colors.white : Colors.black87,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Row 2: Big greeting
                          SlideTransition(
                            position: _greetingSlide,
                            child: FadeTransition(
                              opacity: _greetingFade,
                              child: Text(
                                _getGreeting(),
                                style: GoogleFonts.outfit(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Row 3: Sub-greeting
                          FadeTransition(
                            opacity: _greetingFade,
                            child: Text(
                              _getSubGreeting(),
                              style: GoogleFonts.outfit(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : Colors.black.withValues(alpha: 0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),

                          // Row 4: GPS pill + event counter
                          FadeTransition(
                            opacity: _greetingFade,
                            child: Row(
                              children: [
                                // GPS pill (compact)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isGpsActive
                                        ? Colors.greenAccent.withValues(alpha: 0.4)
                                        : Colors.redAccent.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isGpsActive
                                            ? Icons.my_location_rounded
                                            : Icons.location_off_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isGpsActive
                                            ? 'GPS actif'
                                            : 'GPS désactivé',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Event counter
                                if (!_isLoading && _allEvents.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(0xFF9D4EDD).withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.event_available_rounded,
                                            color: Colors.white,
                                            size: 14),
                                        const SizedBox(width: 4),
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '${_allEvents.length} ',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'événements à découvrir',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Search Bar
                          SlideTransition(
                            position: _searchSlide,
                            child: FadeTransition(
                              opacity: _searchFade,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : Colors.black.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: TextField(
                                      style: GoogleFonts.outfit(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A2E),
                                        fontSize: 16,
                                      ),
                                      onChanged: _onSearchChanged,
                                      decoration: InputDecoration(
                                        hintText: 'Artiste, lieu, ville...',
                                        hintStyle: GoogleFonts.outfit(
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              ],
            ),
            ),
          ),
          ..._buildSliverBody(isDark),
        ],
      ),
    );
  }

  List<Widget> _buildSliverBody(bool isDark) {
    if (_isLoading) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.only(top: 30, bottom: 10, left: 24, right: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Glowing Animated Cloud Icon
                AnimatedBuilder(
                  animation: _navGlowController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 0.9 + (_navGlowController.value * 0.2), // pulses from 0.9 to 1.1
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF9E00)
                                  .withValues(alpha: 0.2 + (_navGlowController.value * 0.4)),
                              blurRadius: 20 + (_navGlowController.value * 20),
                              spreadRadius: 5 + (_navGlowController.value * 10),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.cloud_sync_rounded,
                            size: 35, color: Color(0xFFFF9E00)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
                  ),
                ),
                const SizedBox(height: 24),
                // Texts
                Text('Connexion aux API...',
                    style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Synchronisation des bases de données\nMise à jour de centaines d\'événements...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: 14)),
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  height: 380,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
                  ),
                  child: Shimmer.fromColors(
                    baseColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.15),
                    highlightColor: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.05),
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
      return [SliverToBoxAdapter(child: _buildErrorState(isDark))];
    }

    if (_filteredEvents.isEmpty) {
      return [
        SliverToBoxAdapter(
            child: _buildEmptyState(isDark, isSearch: _searchQuery.isNotEmpty))
      ];
    }

    final int itemCount = _filteredEvents.length > _displayLimit
        ? _displayLimit
        : _filteredEvents.length;
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
                  // HapticFeedback removed for speed
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 400),
                      reverseTransitionDuration:
                          const Duration(milliseconds: 350),
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          EventDetailsScreen(event: _filteredEvents[index]),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
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
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  foregroundColor:
                      isDark ? Colors.white : const Color(0xFF1A1A2E),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  // HapticFeedback removed for speed
                  setState(() {
                    _displayLimit += 50;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Afficher plus d'événements",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
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

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    const Color activeColor = Color(0xFFFF9E00); // Brand orange

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          // HapticFeedback removed for speed
          setState(() => _currentIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white38 : Colors.black38),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white38 : Colors.black38),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            // Simple static dot indicator
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded,
                color: isDark ? Colors.white24 : Colors.black26, size: 48),
            const SizedBox(height: 16),
            Text('Connexion perdue',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 16,
                )),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _refreshEvents,
              style: TextButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: Text('Réessayer',
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, {bool isSearch = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Text(
          isSearch ? 'Aucun résultat trouvé' : 'Aucun événement',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white38 : Colors.black38,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
