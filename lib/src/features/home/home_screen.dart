import 'package:flutter/material.dart';
import '../../models/transit_route.dart';
import '../../models/trips.dart';
import '../../models/station.dart';
import '../../services/melbourne_gtfs_service.dart';
import '../../services/gtfs_parser.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final IGtfsRepository repository;

  const HomeScreen({super.key, required this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  TransitType? _selectedTypeFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Station _selectedStation = MelbourneGtfsService.melbourneHubStations.first;

  List<Trip> _trips = [];
  List<ServiceAlert> _alerts = [];
  List<Station> _stations = MelbourneGtfsService.melbourneHubStations;
  final Set<String> _favoriteTrips = {};
  bool _isLoading = true;
  String? _errorMessage;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMelbourneData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PtvMode get _selectedMode => _selectedTypeFilter == null
      ? PtvMode.metroTrain
      : _mapTransitTypeToPtvMode(_selectedTypeFilter!);

  PtvMode _mapTransitTypeToPtvMode(TransitType type) {
    switch (type) {
      case TransitType.metro:
        return PtvMode.metroTrain;
      case TransitType.tram:
        return PtvMode.metroTram;
      case TransitType.regionalTrain:
        return PtvMode.regionalTrain;
      case TransitType.bus:
        return PtvMode.metroBus;
      case TransitType.ferry:
        return PtvMode.regionalCoach;
    }
  }

  Future<void> _loadMelbourneData({PtvMode? mode, Station? station}) async {
    final requestId = ++_loadRequestId;
    final selectedMode = mode ?? _selectedMode;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dynamicStops = await widget.repository.getStopsForMode(
        selectedMode,
      );

      final rawStations = dynamicStops.isNotEmpty
          ? dynamicStops
          : MelbourneGtfsService.melbourneHubStations;

      final uniqueStations = <String, Station>{};
      for (final s in rawStations) {
        uniqueStations[s.id] = s;
      }
      final stationList = uniqueStations.values.toList();

      final requestedStation = station ?? _selectedStation;
      final currentSelected = stationList.firstWhere(
        (s) => s.id == requestedStation.id,
        orElse: () => stationList.first,
      );
      final trips = await widget.repository.getTripsForMode(
        selectedMode,
        station: currentSelected,
      );
      final alerts = await widget.repository.getServiceAlerts();

      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _trips = trips;
          _alerts = alerts;
          _stations = stationList;
          _selectedStation = currentSelected;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _errorMessage =
              'Unable to load latest timetable. Please try again.';
          _trips = [];
          _alerts = [];
          _stations = MelbourneGtfsService.melbourneHubStations;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Timetable refresh failed.'),
            backgroundColor: AppColors.statusRose,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadMelbourneData,
            ),
          ),
        );
      }
    }
  }

  void _onModeSelected(TransitType? type) {
    setState(() {
      _selectedTypeFilter = type;
    });
    _loadMelbourneData(station: _selectedStation);
  }

  void _onStationSelected(Station station) {
    setState(() => _selectedStation = station);
    _loadMelbourneData(station: station);
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedTypeFilter = null;
    });
    _loadMelbourneData(station: _selectedStation);
  }

  void _toggleFavorite(String tripId) {
    setState(() {
      if (_favoriteTrips.contains(tripId)) {
        _favoriteTrips.remove(tripId);
      } else {
        _favoriteTrips.add(tripId);
      }
    });
  }

  List<Trip> get _filteredTrips {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _trips.where((trip) {
      final departure = trip.departure;
      final matchesType =
          _selectedTypeFilter == null || departure?.type == _selectedTypeFilter;
      final matchesQuery =
          query.isEmpty ||
          trip.headsign.toLowerCase().contains(query) ||
          (trip.shortName?.toLowerCase().contains(query) ?? false) ||
          (departure?.lineCode.toLowerCase().contains(query) ?? false) ||
          (departure?.routeName.toLowerCase().contains(query) ?? false);
      return matchesType && matchesQuery;
    }).toList();

    filtered.sort((a, b) {
      final aTime = a.departure?.scheduledTime;
      final bTime = b.departure?.scheduledTime;
      if (aTime == null || bTime == null) return aTime == null ? 1 : -1;
      return aTime.compareTo(bTime);
    });

    return filtered;
  }

  IconData _getIconForType(TransitType type) {
    switch (type) {
      case TransitType.metro:
        return Icons.subway_rounded;
      case TransitType.tram:
        return Icons.tram_rounded;
      case TransitType.regionalTrain:
        return Icons.train_rounded;
      case TransitType.bus:
        return Icons.directions_bus_rounded;
      case TransitType.ferry:
        return Icons.directions_boat_rounded;
    }
  }

  String _getModeDisplayName(TransitType type) {
    switch (type) {
      case TransitType.metro:
        return 'Metro Train';
      case TransitType.tram:
        return 'Yarra Tram';
      case TransitType.regionalTrain:
        return 'V/Line';
      case TransitType.bus:
        return 'PTV Bus';
      case TransitType.ferry:
        return 'Ferry';
    }
  }

  Color _getStatusColor(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.scheduled:
        return AppColors.primaryCyan;
      case ServiceStatus.onTime:
        return AppColors.statusGreen;
      case ServiceStatus.delayed:
        return AppColors.statusAmber;
      case ServiceStatus.disrupted:
        return AppColors.statusRose;
    }
  }

  String _getStatusText(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.scheduled:
        return 'Scheduled';
      case ServiceStatus.onTime:
        return 'On Time';
      case ServiceStatus.delayed:
        return 'Delayed';
      case ServiceStatus.disrupted:
        return 'Disrupted';
    }
  }

  void _showTripDetailsSheet(Trip trip) {
    final theme = Theme.of(context);
    final departure = trip.departure;
    final badgeColor = departure == null
        ? AppColors.melbourneBus
        : TransitRoute.ptvBrandColor(departure.type);
    final lineCode = departure?.lineCode ?? trip.shortName ?? trip.routeId;
    final scheduledTime = departure?.scheduledTime;
    final timeStr = scheduledTime != null
        ? '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'
        : '--:--';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: badgeColor.withAlpha(80),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          lineCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.headsign,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (departure?.routeName.isNotEmpty ?? false)
                              Text(
                                departure!.routeName,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withAlpha(150),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.dividerColor.withAlpha(40),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDetailItem(
                          icon: Icons.schedule_rounded,
                          label: 'Departure',
                          value: timeStr,
                          color: AppColors.primaryCyan,
                        ),
                        _buildDetailItem(
                          icon: Icons.directions_railway_rounded,
                          label: 'Platform',
                          value: departure?.platform.isNotEmpty == true
                              ? 'Plat ${departure!.platform}'
                              : 'TBA',
                          color: AppColors.secondaryIndigo,
                        ),
                        _buildDetailItem(
                          icon: Icons.accessible_rounded,
                          label: 'Accessibility',
                          value: trip.wheelchairAccessible == 1
                              ? 'Step Free'
                              : 'Standard',
                          color: AppColors.statusGreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Journey Details',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildTimelineItem(
                    title: _selectedStation.name,
                    subtitle: 'Origin Station • Departs $timeStr',
                    isFirst: true,
                    isLast: false,
                    color: AppColors.primaryCyan,
                  ),
                  _buildTimelineItem(
                    title: 'Express Journey to ${trip.headsign}',
                    subtitle: 'Via Direct Route',
                    isFirst: false,
                    isLast: false,
                    color: Colors.grey,
                  ),
                  _buildTimelineItem(
                    title: trip.headsign,
                    subtitle: 'Terminating Station',
                    isFirst: false,
                    isLast: true,
                    color: badgeColor,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required bool isFirst,
    required bool isLast,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: Colors.grey.withAlpha(80),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredTrips = _filteredTrips;
    final isSavedView = _selectedNavIndex == 1;
    final displayedTrips = isSavedView
        ? filteredTrips
              .where((trip) => _favoriteTrips.contains(trip.tripId))
              .toList()
        : filteredTrips;

    final dropdownStations = _stations.isNotEmpty
        ? _stations
        : MelbourneGtfsService.melbourneHubStations;

    final selectedDropdownValue = dropdownStations.contains(_selectedStation)
        ? _selectedStation
        : dropdownStations.firstWhere(
            (s) => s.id == _selectedStation.id,
            orElse: () => dropdownStations.first,
          );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sideMargin = constraints.maxWidth > 840
                ? (constraints.maxWidth - 840) / 2
                : 0.0;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: sideMargin),
              child: RefreshIndicator(
                onRefresh: _loadMelbourneData,
                color: AppColors.primaryCyan,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(20.0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primaryCyan,
                                            AppColors.secondaryIndigo,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryCyan
                                                .withAlpha(90),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.directions_transit_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Melbourne Transit',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.4,
                                                fontSize: 18,
                                              ),
                                        ),
                                        Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: AppColors.statusGreen,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'PTV Live Infrastructure',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: Colors.grey,
                                                    fontSize: 12,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.dividerColor.withAlpha(40),
                                    ),
                                  ),
                                  child: IconButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _loadMelbourneData,
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.refresh_rounded,
                                            size: 20,
                                          ),
                                    tooltip: 'Refresh Feed',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.dividerColor.withAlpha(50),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.primaryCyan,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<Station>(
                                        value: selectedDropdownValue,
                                        isExpanded: true,
                                        icon: const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                        ),
                                        items: dropdownStations.map((station) {
                                          return DropdownMenuItem<Station>(
                                            value: station,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    station.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (station.isCityLoop)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors
                                                          .melbourneMetro
                                                          .withAlpha(45),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'City Loop',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppColors
                                                            .melbourneMetro,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (station) {
                                          if (station != null) {
                                            _onStationSelected(station);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText:
                                    'Search trips, destinations, or lines...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        tooltip: 'Clear search',
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 14),

                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('All Modes'),
                                    selected: _selectedTypeFilter == null,
                                    onSelected: (selected) {
                                      if (selected) {
                                        _onModeSelected(null);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ...TransitType.values
                                      .where(
                                        (type) => type != TransitType.ferry,
                                      )
                                      .map((type) {
                                        final isSelected =
                                            _selectedTypeFilter == type;
                                        final modeName = _getModeDisplayName(
                                          type,
                                        );
                                        final brandColor =
                                            TransitRoute.ptvBrandColor(type);

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8.0,
                                          ),
                                          child: ChoiceChip(
                                            avatar: Icon(
                                              _getIconForType(type),
                                              size: 18,
                                              color: isSelected
                                                  ? Colors.white
                                                  : brandColor,
                                            ),
                                            label: Text(modeName),
                                            selected: isSelected,
                                            selectedColor: brandColor,
                                            onSelected: (selected) {
                                              _onModeSelected(
                                                selected ? type : null,
                                              );
                                            },
                                          ),
                                        );
                                      }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_errorMessage != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 4.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusAmber.withAlpha(26),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.statusAmber.withAlpha(100),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.statusAmber,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadMelbourneData,
                                  child: const Text('Retry'),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                  ),
                                  onPressed: () =>
                                      setState(() => _errorMessage = null),
                                  tooltip: 'Dismiss error message',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (_alerts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 4.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.statusAmber.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.statusAmber.withAlpha(128),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.statusAmber,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _alerts.first.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _alerts.first.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withAlpha(200),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 16,
                        bottom: 8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                isSavedView
                                    ? 'Saved Departures'
                                    : 'Scheduled Departures • ${selectedDropdownValue.name}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.dividerColor.withAlpha(40),
                                ),
                              ),
                              child: Text(
                                '${displayedTrips.length} trips',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryCyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildLoadingCardSkeleton(context),
                            childCount: 3,
                          ),
                        ),
                      )
                    else if (displayedTrips.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.directions_off_rounded,
                                size: 52,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isSavedView
                                    ? 'Save a departure to find it here'
                                    : 'No departures match your filter',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: isSavedView
                                    ? () =>
                                          setState(() => _selectedNavIndex = 0)
                                    : _resetFilters,
                                icon: Icon(
                                  isSavedView
                                      ? Icons.directions_transit_rounded
                                      : Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  isSavedView
                                      ? 'View departures'
                                      : 'Reset & Reload',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final trip = displayedTrips[index];
                            return _buildTripCard(context, trip);
                          }, childCount: displayedTrips.length),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (idx) => setState(() => _selectedNavIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_transit_outlined),
            selectedIcon: Icon(Icons.directions_transit_rounded),
            label: 'Departures',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Saved',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCardSkeleton(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 180,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    final theme = Theme.of(context);
    final departure = trip.departure;
    final isFavorite = _favoriteTrips.contains(trip.tripId);

    final lineCode = departure?.lineCode ?? trip.shortName ?? trip.routeId;
    final badgeColor = departure == null
        ? AppColors.melbourneBus
        : TransitRoute.ptvBrandColor(departure.type);
    final status = departure?.status ?? ServiceStatus.scheduled;
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);
    final minutesAway = departure?.minutesUntil(DateTime.now()) ?? 0;
    final platform = departure?.platform ?? '';
    final scheduledTime = departure?.scheduledTime;
    final routeName = departure?.routeName ?? '';

    final timeString = scheduledTime != null
        ? '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'
        : '';

    return InkWell(
      onTap: () => _showTripDetailsSheet(trip),
      borderRadius: BorderRadius.circular(20),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      lineCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.headsign,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (routeName.isNotEmpty && routeName != trip.headsign)
                          Text(
                            routeName,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                      color: isFavorite ? AppColors.statusAmber : Colors.grey,
                    ),
                    onPressed: () => _toggleFavorite(trip.tripId),
                    tooltip: isFavorite
                        ? 'Remove from saved departures'
                        : 'Save this departure',
                  ),
                ],
              ),
              const Divider(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: AppColors.primaryCyan,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (timeString.isNotEmpty)
                            Text(
                              timeString,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          if (platform.isNotEmpty)
                            Text(
                              'Plat $platform',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(38),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryCyan.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          minutesAway <= 0 ? 'Now' : '$minutesAway min',
                          style: const TextStyle(
                            color: AppColors.primaryCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
