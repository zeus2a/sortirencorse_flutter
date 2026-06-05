import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/event.dart';
import '../utils/app_theme.dart';
import '../utils/search_engine.dart';
import 'event_details_screen.dart';
import 'settings_screen.dart';

class MapScreen extends StatefulWidget {
  final List<Event>? initialEvents;
  final Position? initialPosition;

  const MapScreen({super.key, this.initialEvents, this.initialPosition});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Event> _events = [];
  bool _isLoading = true;
  Position? _userPosition;
  List<Event> _selectedEvents = [];
  final PageController _pageController = PageController(viewportFraction: 0.88);

  // Filters
  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  DateTimeRange? _selectedDateRange;
  int _temporalFilterDays = -1; // 30 = Ce mois, 60 = 2 mois, -1 = Toute la saison

  // Cached categories — computed once, not on every rebuild
  List<String> _cachedCategories = ['Tous'];

  // Corse center
  static const _corseCenter = LatLng(42.15, 9.10);
  static const _defaultZoom = 8.5;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    if (widget.initialEvents != null) {
      _userPosition = widget.initialPosition;
      _events = widget.initialEvents!.where((e) => e.lat != 0.0 && e.lng != 0.0).toList();
      _cachedCategories = _buildCategories();
      _isLoading = false;
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEvents != oldWidget.initialEvents || widget.initialPosition != oldWidget.initialPosition) {
      if (widget.initialEvents != null) {
        setState(() {
          _userPosition = widget.initialPosition;
          _events = widget.initialEvents!.where((e) => e.lat != 0.0 && e.lng != 0.0).toList();
          _cachedCategories = _buildCategories();
        });
      }
    }
  }

  // Events and location are passed from HomeScreen

  // Returns filtered events using the unified SmartSearch engine
  // so the map searches title + location + segmentLabel + description
  // with proper accent normalization — same behavior as the home feed.
  List<Event> get _filteredEvents {
    var results = _events.where((event) {
      // Text search (accent-normalized via SmartSearch helper)
      if (_searchQuery.isNotEmpty) {
        final matched = SmartSearch.matchesQuery(event, _searchQuery);
        if (!matched) return false;
      }
      // Category filter
      if (_selectedCategory != 'Tous' && event.segmentLabel != _selectedCategory) {
        return false;
      }
      // Date range filter
      if (_selectedDateRange != null) {
        final start = _selectedDateRange!.start;
        final end = _selectedDateRange!.end.add(const Duration(days: 1));
        if (event.dateStart.isBefore(start) || event.dateStart.isAfter(end)) {
          return false;
        }
      } else if (_temporalFilterDays > 0) {
        final start = DateTime.now().subtract(const Duration(days: 1));
        final end = DateTime.now().add(Duration(days: _temporalFilterDays));
        if (event.dateStart.isBefore(start) || event.dateStart.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList();
    return results;
  }

  /// Builds and sorts the category list — called once, result cached in _cachedCategories.
  List<String> _buildCategories() {
    final cats = _events.map((e) => e.segmentLabel).where((e) => e.isNotEmpty).toSet().toList();
    cats.sort((a, b) {
      int getScore(String cat) {
        final c = cat.toLowerCase();
        if (c.contains('polyphonie')) return 1;
        if (c.contains('concert')) return 2;
        if (c.contains('festival')) return 3;
        if (c.contains('soirée') || c.contains('soiree') || c.contains('dj')) return 4;
        if (c.contains('theatre') || c.contains('théâtre') || c.contains('danse')) return 999;
        return 50;
      }
      final scoreA = getScore(a);
      final scoreB = getScore(b);
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      return a.compareTo(b);
    });
    return ['Tous', ...cats];
  }

  void _openEventDetail(Event event) {
    Navigator.push(context, AppRoutes.slideUp(EventDetailsScreen(event: event)));
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
                  color: isDark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
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
                    const SizedBox(height: 16),
                    CalendarDatePicker2(
                      config: CalendarDatePicker2Config(
                        calendarType: CalendarDatePicker2Type.range,
                        firstDate: initialDate,
                        lastDate: DateTime(now.year + 2),
                        selectedDayHighlightColor: const Color(0xFFFF9E00),
                        selectedRangeHighlightColor: const Color(0xFFFF9E00).withValues(alpha: 0.15),
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
                                        start: tempValues[0]!, end: tempValues[0]!);
                                  } else if (tempValues.length >= 2) {
                                    _selectedDateRange = DateTimeRange(
                                        start: tempValues[0]!,
                                        end: tempValues[1] ?? tempValues[0]!);
                                  }
                                  _selectedEvents = [];
                                });
                                Navigator.pop(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9E00),
                          disabledBackgroundColor: isDark ? Colors.white12 : Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          '✔ VALIDER LA PÉRIODE',
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
                    if (tempValues.isNotEmpty || _selectedDateRange != null) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDateRange = null;
                            tempValues = [];
                            _selectedEvents = [];
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Effacer le filtre',
                          style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 14),
                        ),
                      ),
                    ],
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

  void _cycleTemporalFilter() {
    setState(() {
      if (_selectedDateRange != null) {
        _selectedDateRange = null;
        _temporalFilterDays = 30;
      } else if (_temporalFilterDays == -1) {
        _temporalFilterDays = 30;
      } else if (_temporalFilterDays == 30) {
        _temporalFilterDays = 60;
      } else {
        _temporalFilterDays = -1;
      }
      _selectedEvents = [];
    });
  }

  void _cycleCategoryFilter() {
    setState(() {
      int currentIndex = _cachedCategories.indexOf(_selectedCategory);
      if (currentIndex == -1 || currentIndex == _cachedCategories.length - 1) {
        _selectedCategory = _cachedCategories[0]; // 'Tous'
      } else {
        _selectedCategory = _cachedCategories[currentIndex + 1];
      }
      _selectedEvents = [];
    });
  }

  Widget _buildUnifiedTemporalChip(bool isDark) {
    String label = 'Toute la saison';
    String? subLabel;
    bool isLocked = false;
    
    if (_selectedDateRange != null) {
      label = 'Dates précises';
      isLocked = true;
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end;
      final startStr = '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}/${start.year}';
      final endStr = '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}';
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        subLabel = startStr;
      } else {
        subLabel = 'Du $startStr au $endStr';
      }
    } else if (_temporalFilterDays == 30) {
      label = 'Ce mois';
    } else if (_temporalFilterDays == 60) {
      label = '2 mois';
    }
    
    final isActive = _selectedDateRange != null || _temporalFilterDays != -1;

    return GestureDetector(
      onTap: isLocked ? null : _cycleTemporalFilter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive 
              ? (isDark ? Colors.black.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.8))
              : (isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isActive 
                  ? const Color(0xFFFF9E00)
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2))),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.event_available_rounded : Icons.calendar_today_rounded, 
                 color: isActive ? const Color(0xFFFF9E00) : (isDark ? Colors.white70 : Colors.black87), 
                 size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: isActive ? const Color(0xFFFF9E00) : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subLabel != null)
                    Text(
                      subLabel,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFF9E00).withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortenCategory(String cat) {
    if (cat.toLowerCase().contains('culturel')) return 'Culture';
    return cat;
  }

  Widget _buildUnifiedCategoryChip(bool isDark) {
    final isActive = _selectedCategory != 'Tous';
    final displayName = isActive ? _shortenCategory(_selectedCategory) : 'Tous les genres';
    
    return GestureDetector(
      onTap: _cycleCategoryFilter,
      child: Container(
        width: 150, // Fixe la taille à 150 pixels
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? (isDark ? Colors.black.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.8))
              : (isDark ? Colors.black.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive 
                  ? const Color(0xFFFF9E00)
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2))),
        ),
        alignment: Alignment.center, // Centre le texte si la cellule est plus grande
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActive) ...[
              Icon(
                Event.getCategoryStyle(_selectedCategory)['icon'],
                color: const Color(0xFFFF9E00),
                size: 14,
              ),
              const SizedBox(width: 4),
            ] else ...[
               Icon(Icons.category_rounded, color: isDark ? Colors.white70 : Colors.black87, size: 14),
               const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                displayName,
                style: GoogleFonts.outfit(
                  color: isActive ? const Color(0xFFFF9E00) : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredEvents = _filteredEvents;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF9E00)),
            const SizedBox(height: 16),
            Text(
              'Chargement de la carte...',
              style: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userPosition != null
                ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                : _corseCenter,
            initialZoom: _userPosition != null ? 11.0 : _defaultZoom,
            onTap: (_, __) => setState(() {
              _selectedEvents = [];
              FocusScope.of(context).unfocus();
            }),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
          ),
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.black26, // "Sunglass" effect to reduce glare
                BlendMode.darken,
              ),
              child: TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.zeus2a.sortirencorse',
                maxZoom: 19,
              ),
            ),
            if (_userPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            MarkerClusterLayerWidget(
              key: ValueKey('${filteredEvents.length}_${_selectedCategory}_${_searchQuery}_${_selectedDateRange?.start}'),
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 45,
                size: const Size(40, 40),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(50),
                maxZoom: 15,
                markers: () {
                  final Map<String, List<Event>> grouped = {};
                  for (final e in filteredEvents) {
                    final k = '${e.lat.toStringAsFixed(4)},${e.lng.toStringAsFixed(4)}';
                    grouped.putIfAbsent(k, () => []).add(e);
                  }
                  
                  return grouped.values.map((eventsGroup) {
                    final event = eventsGroup.first;
                    final isSelected = _selectedEvents.isNotEmpty && _selectedEvents.first.id == event.id;
                    final style = Event.getCategoryStyle(event.segmentLabel);
                    Color markerColor = style['color'];
                    IconData markerIcon = style['icon'];
                    
                    return Marker(
                      key: ValueKey(event.id),
                      point: LatLng(event.lat, event.lng),
                      width: isSelected ? 50 : 40,
                      height: isSelected ? 50 : 40,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedEvents = eventsGroup;
                          });
                          _mapController.move(LatLng(event.lat, event.lng), 14);
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(0);
                          }
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSelected ? 44 : 36,
                              height: isSelected ? 44 : 36,
                              decoration: BoxDecoration(
                                color: isSelected ? markerColor : markerColor.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: markerColor.withValues(alpha: isSelected ? 0.6 : 0.3),
                                    blurRadius: isSelected ? 16 : 8,
                                    spreadRadius: isSelected ? 4 : 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  markerIcon,
                                  color: Colors.white,
                                  size: isSelected ? 22 : 16,
                                ),
                              ),
                            ),
                            if (eventsGroup.length > 1)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: Text(
                                    eventsGroup.length.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList();
                }(),
                builder: (context, markers) {
                  String category = 'other';
                  if (markers.isNotEmpty && markers.first.key is ValueKey) {
                    category = (markers.first.key as ValueKey).value.toString();
                  }
                  Color clusterColor = category == 'party' ? Colors.purple : Colors.amber;

                  return Container(
                    decoration: BoxDecoration(
                      color: clusterColor.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: clusterColor.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        markers.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // --- NOUVEAU HEADER (Style Airbnb) ---
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Barre de Recherche Flottante
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.search_rounded, color: Colors.grey, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.outfit(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Rechercher (ex: L\'Alba)...',
                                hintStyle: GoogleFonts.outfit(
                                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                          InkWell(
                            onTap: _showCalendarPicker,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: _selectedDateRange != null ? Colors.redAccent : const Color(0xFFFF9E00),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 2. Ligne de Filtres (Chips)
              SizedBox(
                height: 48,
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Chip Temporal Actif
                        _buildUnifiedTemporalChip(isDark),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 20, color: Colors.grey.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(vertical: 8)),
                        const SizedBox(width: 8),
                        // Categories Unified Chip
                        _buildUnifiedCategoryChip(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // --- NOUVEAU BOUTON GPS (Bas Centre, au-dessus du compteur) ---
        if (_selectedEvents.isEmpty)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 160, // Calcul exact: menu (70) + margin (20) + gap GPS (70)
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                heroTag: 'map_gps_fab',
                mini: true,
                backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
                elevation: 4,
                onPressed: () {
                  _mapController.move(
                    _userPosition != null && SettingsScreen.isGpsEnabled
                        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
                        : _corseCenter,
                    _userPosition != null && SettingsScreen.isGpsEnabled ? 11.0 : _defaultZoom,
                  );
                  setState(() => _selectedEvents = []);
                },
                child: Icon(
                  Icons.my_location_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),

        // --- NOUVEAU COMPTEUR D'EVENEMENTS (Bas Centre) ---
        if (_selectedEvents.isEmpty)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 110, // Calcul exact: menu (70) + margin (20) + gap (20)
            left: 0, // IMPORTANT: Ajouté pour que le Center fonctionne !
            right: 0, // IMPORTANT: Ajouté pour que le Center fonctionne !
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map_rounded, color: Color(0xFFFF9E00), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${filteredEvents.length} événements',
                        style: GoogleFonts.outfit(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (_selectedEvents.isNotEmpty)
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 400, // Large height for central cards
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: _selectedEvents.length,
                itemBuilder: (context, index) {
                  final ev = _selectedEvents[index];
                  final distanceStr = ev.distanceLabelShort;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () => _openEventDetail(ev),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Big Image on Top
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(18),
                                        child: ev.imageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: ev.imageUrl,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  width: double.infinity,
                                                  color: isDark ? Colors.white10 : Colors.black12,
                                                ),
                                                errorWidget: (context, url, error) => Container(
                                                  width: double.infinity,
                                                  color: isDark ? const Color(0xFF1A1A2E) : Colors.grey.shade200,
                                                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                                ),
                                              )
                                            : Container(
                                                width: double.infinity,
                                                color: const Color(0xFF1A1A2E),
                                                child: const Icon(Icons.event, color: Color(0xFFFF9E00), size: 48),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // Details Section
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Type of event
                                              Builder(
                                                builder: (context) {
                                                  final style = Event.getCategoryStyle(ev.segmentLabel);
                                                  final color = style['color'] as Color;
                                                  final icon = style['icon'] as IconData;
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: color.withValues(alpha: 0.30),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                        color: color.withValues(alpha: 0.5),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(icon, color: Colors.white, size: 12),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          ev.segmentLabel.toUpperCase(),
                                                          style: GoogleFonts.outfit(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w800,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                              ),
                                              const SizedBox(height: 10),
                                              // Title
                                              Text(
                                                ev.title,
                                                style: GoogleFonts.outfit(
                                                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.1,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              // Date
                                              Row(
                                                children: [
                                                  Icon(Icons.calendar_month_rounded, color: isDark ? Colors.white54 : Colors.black45, size: 14),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      '${ev.dateStart.day.toString().padLeft(2, '0')}/${ev.dateStart.month.toString().padLeft(2, '0')}/${ev.dateStart.year} à ${ev.dateStart.hour}h${ev.dateStart.minute.toString().padLeft(2, '0')}',
                                                      style: GoogleFonts.outfit(
                                                        color: isDark ? Colors.white70 : Colors.black87,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              // Address
                                              Row(
                                                children: [
                                                  Icon(Icons.place_outlined, color: isDark ? Colors.white54 : Colors.black45, size: 14),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      ev.locationAddress,
                                                      style: GoogleFonts.outfit(
                                                        color: isDark ? Colors.white54 : Colors.black54,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w400,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // Distance (if GPS is enabled and calculated)
                                              if (distanceStr.isNotEmpty && SettingsScreen.isGpsEnabled) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.near_me_rounded, color: Colors.blueAccent, size: 12),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      distanceStr,
                                                      style: GoogleFonts.outfit(
                                                        color: isDark ? Colors.white54 : Colors.black45,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
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
                                    const SizedBox(height: 12),
                                    // Affordance Indicator
                                    Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Appuyez pour voir les détails',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFFFF9E00).withValues(alpha: 0.8),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_rounded, color: const Color(0xFFFF9E00).withValues(alpha: 0.8), size: 14),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Close Button
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedEvents = []),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                                // Counter if multiple
                                if (_selectedEvents.length > 1)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white24 : Colors.black12,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${index + 1} / ${_selectedEvents.length}',
                                        style: GoogleFonts.outfit(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
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
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
