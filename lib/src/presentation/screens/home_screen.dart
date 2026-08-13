import 'package:flutter/material.dart';
import '../../data/repositories/gtfs_repository.dart';
import '../state/transit_view_model.dart';
import '../widgets/app_header_widget.dart';
import '../widgets/station_selector_card.dart';
import '../widgets/mode_filter_bar.dart';
import '../widgets/trip_card_widget.dart';
import '../widgets/trip_details_sheet.dart';
import '../widgets/alert_banner_widget.dart';
import '../widgets/empty_state_widget.dart';
import 'disruptions_screen.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final IGtfsRepository repository;

  const HomeScreen({super.key, required this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TransitViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = TransitViewModel(repository: widget.repository);
    _viewModel.addListener(_onViewModelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadMelbourneData();
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
            alerts: _viewModel.alerts,
            isLoading: _viewModel.isLoading,
            onRefresh: _viewModel.loadMelbourneData,
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
                onRefresh: _viewModel.loadMelbourneData,
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
                              onRefresh: _viewModel.loadMelbourneData,
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

                            StationSelectorCard(
                              selectedStation: _viewModel.selectedStation,
                              stations: _viewModel.stations,
                              onStationSelected: _viewModel.selectStation,
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _searchController,
                              onChanged: _viewModel.updateSearchQuery,
                              decoration: InputDecoration(
                                hintText:
                                    'Search destinations, trips, or lines...',
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
                                  onPressed: _viewModel.loadMelbourneData,
                                  child: const Text('Retry'),
                                ),
                              ],
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
                              isFavorite: _viewModel.isFavorite(trip.tripId),
                              onToggleFavorite: () =>
                                  _viewModel.toggleFavorite(trip.tripId),
                              onTap: () => TripDetailsSheet.show(
                                context,
                                trip: trip,
                                selectedStation: _viewModel.selectedStation,
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
        const NavigationDestination(
          icon: Icon(Icons.star_outline_rounded),
          selectedIcon: Icon(Icons.star_rounded),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: _viewModel.alerts.isNotEmpty,
            label: Text('${_viewModel.alerts.length}'),
            child: const Icon(Icons.warning_amber_rounded),
          ),
          selectedIcon: Badge(
            isLabelVisible: _viewModel.alerts.isNotEmpty,
            label: Text('${_viewModel.alerts.length}'),
            child: const Icon(Icons.warning_rounded),
          ),
          label: 'Disruptions',
        ),
      ],
    );
  }
}
