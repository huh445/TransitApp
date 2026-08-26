import 'package:flutter/material.dart';
import '../../data/repositories/gtfs_repository.dart';
import '../../services/ptv_rt_service.dart';
import '../../theme/app_theme.dart';
import '../state/transit_view_model.dart';
import '../widgets/alert_banner_widget.dart';
import '../widgets/app_header_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/mode_filter_bar.dart';
import '../widgets/station_selector_card.dart';
import '../widgets/trip_card_widget.dart';
import '../widgets/trip_details_sheet.dart';
import '../widgets/live_ride_sheet.dart';
import 'disruptions_screen.dart';

class HomeScreen extends StatefulWidget {
  final IGtfsRepository repository;
  final PtvRealtimeService? ptvService;

  const HomeScreen({
    super.key,
    required this.repository,
    this.ptvService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TransitViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = TransitViewModel(
      repository: widget.repository,
      ptvService: widget.ptvService,
    );
    _viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadData();
    });
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedTrips = _viewModel.displayedTrips;
    final isSavedView = _viewModel.selectedNavIndex == 1;
    final isDisruptionsView = _viewModel.selectedNavIndex == 2;

    if (isDisruptionsView) {
      return Scaffold(
        body: SafeArea(
          child: DisruptionsScreen(
            alerts: _viewModel.favoriteStationDisruptions,
            allAlerts: _viewModel.alerts,
            favoriteStations: _viewModel.favoriteStations,
            selectedStation: _viewModel.selectedStation,
            isLoading: _viewModel.isLoading,
            onRefresh: _viewModel.loadData,
          ),
        ),
        bottomNavigationBar: _buildNavigationBar(),
      );
    }

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
                onRefresh: _viewModel.loadData,
                color: AppColors.primaryCyan,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(20.0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppHeaderWidget(
                              isLoading: _viewModel.isLoading,
                              loadingProgress: _viewModel.loadingProgress,
                              loadingPercentage: _viewModel.loadingPercentage,
                              loadingStatus: _viewModel.loadingStatus,
                              onRefresh: _viewModel.loadData,
                            ),
                            if (_viewModel.isLoading) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _viewModel.loadingProgress > 0.0
                                      ? _viewModel.loadingProgress
                                      : null,
                                  backgroundColor: theme.cardColor,
                                  color: AppColors.primaryCyan,
                                  minHeight: 6,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),

                            // Station Selector Card with Instant Search & Favorite Action
                            StationSelectorCard(
                              selectedStation: _viewModel.selectedStation,
                              stations: _viewModel.stations,
                              favoriteStations: _viewModel.favoriteStations,
                              recentStations: _viewModel.recentStations,
                              userPosition: _viewModel.userPosition,
                              onLocateNearest: _viewModel.locateNearestStation,
                              onStationSelected: _viewModel.selectStation,
                              onToggleFavorite: _viewModel.toggleFavoriteStation,
                            ),
                            const SizedBox(height: 14),

                            // Search departures/routes
                            TextField(
                              controller: _searchController,
                              onChanged: _viewModel.updateSearchQuery,
                              decoration: InputDecoration(
                                hintText: 'Search destinations, trips, or lines...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _viewModel.searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () {
                                          _searchController.clear();
                                          _viewModel.updateSearchQuery('');
                                        },
                                        tooltip: 'Clear search',
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Mode Filter Chips
                            ModeFilterBar(
                              selectedTypeFilter: _viewModel.selectedTypeFilter,
                              onModeSelected: _viewModel.selectModeFilter,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_viewModel.errorMessage != null)
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
                                    _viewModel.errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _viewModel.loadData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Active Ride in Progress Floating Banner
                    if (_viewModel.isTrackingActive && _viewModel.activeTrackedTrip != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 6.0,
                          ),
                          child: InkWell(
                            onTap: () => LiveRideSheet.show(context, _viewModel),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryCyan,
                                    AppColors.secondaryIndigo,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryCyan.withAlpha(90),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(30),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.gps_fixed_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'ON-BOARD TRACKING ACTIVE',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'To ${_viewModel.activeTrackedTrip!.destinationName} • Current: ${_viewModel.currentStopStation?.name ?? _viewModel.onBoardStation?.name ?? _viewModel.selectedStation.name}${_viewModel.nextStopStation != null ? ' • Next: ${_viewModel.nextStopStation!.name}' : ''}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (_viewModel.alerts.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 4.0,
                          ),
                          child: AlertBannerWidget(
                            alert: _viewModel.alerts.first,
                          ),
                        ),
                      ),

                    // Saved View: Favorite Stations Section
                    if (isSavedView && _viewModel.favoriteStations.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'FAVORITE STATIONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: theme.textTheme.bodySmall?.color?.withAlpha(150),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final st = _viewModel.favoriteStations[index];
                            final isSelected = st.name == _viewModel.selectedStation.name;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.statusAmber,
                                ),
                                title: Text(
                                  st.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(st.zone.isNotEmpty ? st.zone : 'Zone 1'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: () => _viewModel.toggleFavoriteStation(st),
                                  tooltip: 'Remove Favorite',
                                ),
                                onTap: () {
                                  _viewModel.selectStation(st);
                                  _viewModel.selectNavIndex(0); // switch to departures
                                },
                              ),
                            );
                          }, childCount: _viewModel.favoriteStations.length),
                        ),
                      ),
                    ],

                    // Saved View: Recent Stations Section (if no favorites or as complementary list)
                    if (isSavedView && _viewModel.recentStations.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'RECENT STATIONS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: theme.textTheme.bodySmall?.color?.withAlpha(150),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final st = _viewModel.recentStations[index];
                            final isSelected = st.name == _viewModel.selectedStation.name;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.history_rounded,
                                  color: AppColors.secondaryIndigo,
                                ),
                                title: Text(
                                  st.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(st.zone.isNotEmpty ? st.zone : 'Zone 1'),
                                onTap: () {
                                  _viewModel.selectStation(st);
                                  _viewModel.selectNavIndex(0); // switch to departures
                                },
                              ),
                            );
                          }, childCount: _viewModel.recentStations.length),
                        ),
                      ),
                    ],

                    // Section Title Header
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
                                    : 'Scheduled Departures • ${_viewModel.selectedStation.name}',
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

                    if (_viewModel.isLoading)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Card(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Container(
                                      height: 20,
                                      color: Colors.white10,
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      height: 14,
                                      color: Colors.white10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            childCount: 3,
                          ),
                        ),
                      )
                    else if (displayedTrips.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateWidget(
                          isSavedView: isSavedView,
                          onReset: isSavedView
                              ? () => _viewModel.selectNavIndex(0)
                              : _viewModel.resetFilters,
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
                            return TripCardWidget(
                              trip: trip,
                              isFavorite: _viewModel.isFavoriteTrip(trip.tripId),
                              hasDisruption: _viewModel.hasDisruptionForTrip(trip),
                              onToggleFavorite: () =>
                                  _viewModel.toggleFavoriteTrip(trip.tripId),
                              onTap: () => TripDetailsSheet.show(
                                context,
                                trip: trip,
                                selectedStation: _viewModel.selectedStation,
                                viewModel: _viewModel,
                              ),
                            );
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
      bottomNavigationBar: _buildNavigationBar(),
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _viewModel.selectedNavIndex,
      onDestinationSelected: _viewModel.selectNavIndex,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.directions_transit_outlined),
          selectedIcon: Icon(Icons.directions_transit_rounded),
          label: 'Departures',
        ),
        NavigationDestination(
          icon: const Icon(Icons.star_outline_rounded),
          selectedIcon: const Icon(Icons.star_rounded),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: _viewModel.favoriteStationDisruptions.isNotEmpty,
            label: Text('${_viewModel.favoriteStationDisruptions.length}'),
            child: const Icon(Icons.warning_amber_rounded),
          ),
          selectedIcon: Badge(
            isLabelVisible: _viewModel.favoriteStationDisruptions.isNotEmpty,
            label: Text('${_viewModel.favoriteStationDisruptions.length}'),
            child: const Icon(Icons.warning_rounded),
          ),
          label: 'Disruptions',
        ),
      ],
    );
  }
}
