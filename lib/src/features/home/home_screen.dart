import 'package:flutter/material.dart';
import '../../models/transit_route.dart';
import '../../models/station.dart';
import '../../services/melbourne_gtfs_service.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  TransitType? _selectedTypeFilter;
  String _searchQuery = '';
  Station _selectedStation = MelbourneGtfsService.melbourneHubStations.first;

  late List<TransitRoute> _routes;
  late List<ServiceAlert> _alerts;

  @override
  void initState() {
    super.initState();
    _loadMelbourneData();
  }

  void _loadMelbourneData() {
    _routes = MelbourneGtfsService.getMelbourneRoutes();
    _alerts = MelbourneGtfsService.getMelbourneAlerts();
  }

  void _toggleFavorite(String routeId) {
    setState(() {
      final index = _routes.indexWhere((r) => r.id == routeId);
      if (index != -1) {
        _routes[index] = _routes[index].copyWith(
          isFavorite: !_routes[index].isFavorite,
        );
      }
    });
  }

  List<TransitRoute> get _filteredRoutes {
    return _routes.where((route) {
      final matchesType =
          _selectedTypeFilter == null || route.type == _selectedTypeFilter;
      final matchesQuery = _searchQuery.isEmpty ||
          route.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          route.lineCode.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesType && matchesQuery;
    }).toList();
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
      case ServiceStatus.onTime:
        return 'On Time';
      case ServiceStatus.delayed:
        return 'Delayed';
      case ServiceStatus.disrupted:
        return 'Disrupted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Custom PTV Melbourne App Bar
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.melbourneMetro.withAlpha(38),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_transit_rounded,
                                color: AppColors.melbourneMetro,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Melbourne Transit',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'PTV Network & GTFS Infrastructure',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Updating PTV live departures...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Refresh GTFS Feed',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Station / Hub Selector Dropdown Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: AppColors.primaryCyan, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Station>(
                                value: _selectedStation,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                items: MelbourneGtfsService.melbourneHubStations
                                    .map((station) {
                                  return DropdownMenuItem<Station>(
                                    value: station,
                                    child: Row(
                                      children: [
                                        Text(
                                          station.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        if (station.isCityLoop)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.melbourneMetro
                                                  .withAlpha(50),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'City Loop',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.melbourneMetro,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (st) {
                                  if (st != null) {
                                    setState(() => _selectedStation = st);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search Input Bar
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search lines, routes, or GTFS code...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mode Filter Chips with Melbourne PTV Colors
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All Modes'),
                            selected: _selectedTypeFilter == null,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedTypeFilter = null);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ...TransitType.values.map((type) {
                            final isSelected = _selectedTypeFilter == type;
                            final modeName = _getModeDisplayName(type);
                            final brandColor = TransitRoute.ptvBrandColor(type);

                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                avatar: Icon(
                                  _getIconForType(type),
                                  size: 18,
                                  color: isSelected ? Colors.white : brandColor,
                                ),
                                label: Text(modeName),
                                selected: isSelected,
                                selectedColor: brandColor,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTypeFilter = selected ? type : null;
                                  });
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

            // Melbourne Service Alert Banner
            if (_alerts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                  color: theme.textTheme.bodyMedium?.color
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

            // Section Header: Departures at Selected Station
            SliverPadding(
              padding:
                  const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Departures • ${_selectedStation.code}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_filteredRoutes.length} GTFS routes',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // Route List
            _filteredRoutes.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.directions_off_rounded,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Melbourne routes match your filter',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final route = _filteredRoutes[index];
                          return _buildRouteCard(context, route);
                        },
                        childCount: _filteredRoutes.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (idx) => setState(() => _selectedNavIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_transit_outlined),
            selectedIcon: Icon(Icons.directions_transit_rounded),
            label: 'Routes',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Network Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'PTV Alerts',
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, TransitRoute route) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Line Code + Route Name + Favorite Toggle
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: route.badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    route.lineCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    route.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    route.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: route.isFavorite
                        ? AppColors.statusAmber
                        : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(route.id),
                ),
              ],
            ),
            const Divider(height: 20),

            // Departures List
            ...route.departures.map((departure) {
              final statusColor = _getStatusColor(departure.status);
              final statusText = _getStatusText(departure.status);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.primaryCyan,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              departure.destination,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              departure.platform,
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
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(38),
                            borderRadius: BorderRadius.circular(6),
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
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryCyan.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${departure.minutesAway} min',
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
              );
            }),
          ],
        ),
      ),
    );
  }
}
