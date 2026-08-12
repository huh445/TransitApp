import '../models/service.dart';
import '../models/station.dart';
import '../models/transit_route.dart';

/// Dedicated service providing GTFS infrastructure integration for Melbourne's PTV network.
class MelbourneGtfsService {
  /// Major Melbourne network hubs and City Loop stations.
  static final List<Station> melbourneHubStations = [
    const Station(
      id: 'st_flinders',
      stopId: '19842',
      name: 'Flinders Street Station',
      code: 'FSS',
      lat: -37.8183,
      lon: 144.9671,
      suburb: 'Melbourne CBD',
      zone: 'Zone 1',
      isCityLoop: true,
      routes: [],
    ),
    const Station(
      id: 'st_southern_cross',
      stopId: '22180',
      name: 'Southern Cross Station',
      code: 'SSS',
      lat: -37.8185,
      lon: 144.9525,
      suburb: 'Docklands / CBD',
      zone: 'Zone 1',
      isCityLoop: true,
      routes: [],
    ),
    const Station(
      id: 'st_melbourne_central',
      stopId: '19843',
      name: 'Melbourne Central Station',
      code: 'MCE',
      lat: -37.8102,
      lon: 144.9628,
      suburb: 'Melbourne CBD',
      zone: 'Zone 1',
      isCityLoop: true,
      routes: [],
    ),
    const Station(
      id: 'st_parliament',
      stopId: '19844',
      name: 'Parliament Station',
      code: 'PAR',
      lat: -37.8113,
      lon: 144.9729,
      suburb: 'Melbourne CBD',
      zone: 'Zone 1',
      isCityLoop: true,
      routes: [],
    ),
    const Station(
      id: 'st_footscray',
      stopId: '19982',
      name: 'Footscray Station',
      code: 'FSY',
      lat: -37.8013,
      lon: 144.9030,
      suburb: 'Footscray',
      zone: 'Zone 1',
      isCityLoop: false,
      routes: [],
    ),
    const Station(
      id: 'st_geelong',
      stopId: '20291',
      name: 'Geelong Station',
      code: 'GLG',
      lat: -38.1448,
      lon: 144.3541,
      suburb: 'Geelong',
      zone: 'Regional (Zone 4)',
      isCityLoop: false,
      routes: [],
    ),
  ];

  /// Returns sample real-time Melbourne PTV GTFS transit routes.
  static List<TransitRoute> getMelbourneRoutes() {
    final now = DateTime.now();

    return [
      TransitRoute(
        id: 'melb_r1',
        routeId: '2-BEL-F-mjp-1',
        lineCode: 'BEL',
        name: 'Belgrave Line (Flinders St via City Loop)',
        type: TransitType.metro,
        badgeColor: TransitRoute.ptvBrandColor(TransitType.metro),
        isFavorite: true,
        departures: [
          Departure(
            destination: 'Belgrave',
            platform: 'Platform 1',
            scheduledTime: now.add(const Duration(minutes: 3)),
            minutesAway: 3,
            status: ServiceStatus.onTime,
          ),
          Departure(
            destination: 'Lilydale',
            platform: 'Platform 2',
            scheduledTime: now.add(const Duration(minutes: 11)),
            minutesAway: 11,
            status: ServiceStatus.onTime,
          ),
        ],
      ),
      TransitRoute(
        id: 'melb_r2',
        routeId: '2-FKN-F-mjp-1',
        lineCode: 'FKN',
        name: 'Frankston Line (Express via Richmond)',
        type: TransitType.metro,
        badgeColor: TransitRoute.ptvBrandColor(TransitType.metro),
        isFavorite: true,
        departures: [
          Departure(
            destination: 'Frankston',
            platform: 'Platform 7',
            scheduledTime: now.add(const Duration(minutes: 5)),
            minutesAway: 5,
            status: ServiceStatus.onTime,
          ),
          Departure(
            destination: 'Mordialloc',
            platform: 'Platform 6',
            scheduledTime: now.add(const Duration(minutes: 17)),
            minutesAway: 17,
            status: ServiceStatus.delayed,
          ),
        ],
      ),
      TransitRoute(
        id: 'melb_r3',
        routeId: '3-096-mjp-1',
        lineCode: 'Route 96',
        name: 'East Brunswick - St Kilda Beach',
        type: TransitType.tram,
        badgeColor: TransitRoute.ptvBrandColor(TransitType.tram),
        isFavorite: true,
        departures: [
          Departure(
            destination: 'St Kilda Beach',
            platform: 'Stop 122',
            scheduledTime: now.add(const Duration(minutes: 2)),
            minutesAway: 2,
            status: ServiceStatus.onTime,
          ),
          Departure(
            destination: 'East Brunswick',
            platform: 'Stop 122',
            scheduledTime: now.add(const Duration(minutes: 9)),
            minutesAway: 9,
            status: ServiceStatus.onTime,
          ),
        ],
      ),
      TransitRoute(
        id: 'melb_r4',
        routeId: '3-109-mjp-1',
        lineCode: 'Route 109',
        name: 'Box Hill - Port Melbourne',
        type: TransitType.tram,
        badgeColor: TransitRoute.ptvBrandColor(TransitType.tram),
        isFavorite: false,
        departures: [
          Departure(
            destination: 'Port Melbourne',
            platform: 'Stop 5 (Collins St)',
            scheduledTime: now.add(const Duration(minutes: 6)),
            minutesAway: 6,
            status: ServiceStatus.onTime,
          ),
        ],
      ),
      TransitRoute(
        id: 'melb_r5',
        routeId: '1-GEE-mjp-1',
        lineCode: 'V/Line GEE',
        name: 'Geelong Line (Southern Cross to Waurn Ponds)',
        type: TransitType.regionalTrain,
        badgeColor: TransitRoute.ptvBrandColor(TransitType.regionalTrain),
        isFavorite: true,
        departures: [
          Departure(
            destination: 'Waurn Ponds via Geelong',
            platform: 'Platform 3B',
            scheduledTime: now.add(const Duration(minutes: 14)),
            minutesAway: 14,
            status: ServiceStatus.onTime,
          ),
        ],
      ),
      TransitRoute(
        id: 'melb_r6',
        routeId: '6-903-mjp-1',
        lineCode: 'SmartBus 903',
        name: 'Altona to Mordialloc (Orbital Cross-City)',
        type: TransitType.bus,
        badgeColor: TransitRoute.ptvBrandColor(TransitType.bus),
        isFavorite: false,
        departures: [
          Departure(
            destination: 'Mordialloc Station',
            platform: 'Bay 4',
            scheduledTime: now.add(const Duration(minutes: 8)),
            minutesAway: 8,
            status: ServiceStatus.delayed,
          ),
        ],
      ),
      TransitRoute(
        id: 'melb_r7',
        routeId: '10-PPF-mjp-1',
        lineCode: 'Ferry',
        name: 'Port Phillip Ferry (Docklands to Portarlington)',
        type: TransitType.ferry,
        badgeColor: TransitRoute.ptvBrandColor(TransitType.ferry),
        isFavorite: false,
        departures: [
          Departure(
            destination: 'Portarlington Pier',
            platform: 'Victoria Harbour Berth 1',
            scheduledTime: now.add(const Duration(minutes: 35)),
            minutesAway: 35,
            status: ServiceStatus.onTime,
          ),
        ],
      ),
    ];
  }

  /// Active Melbourne GTFS PTV network service alerts.
  static List<ServiceAlert> getMelbourneAlerts() {
    final now = DateTime.now();

    return [
      ServiceAlert(
        id: 'melb_alt_1',
        title: 'Metro Tunnel Connection Trackwork',
        description:
            'Buses replace Metro trains between Parliament and Caulfield due to signaling upgrades.',
        lineCode: 'FKN',
        timestamp: now.subtract(const Duration(minutes: 30)),
        severity: ServiceStatus.disrupted,
      ),
      ServiceAlert(
        id: 'melb_alt_2',
        title: 'Bourke St Tram Diversion',
        description: 'Yarra Tram Route 96 operating with minor 5-min delays through CBD.',
        lineCode: 'Route 96',
        timestamp: now.subtract(const Duration(minutes: 10)),
        severity: ServiceStatus.delayed,
      ),
    ];
  }

  /// Builds a sample GTFS Service schedule for a trip between Flinders St and Belgrave.
  static Service getBelgraveExpressService() {
    final now = DateTime.now();
    final flinders = melbourneHubStations.firstWhere((s) => s.code == 'FSS');
    final southernCross = melbourneHubStations.firstWhere((s) => s.code == 'SSS');

    return Service(
      id: 'srv_bel_01',
      tripId: 'GTFS-TRIP-BEL-9401',
      routeId: '2-BEL-F-mjp-1',
      serviceNumber: 'BEL-9401',
      headsign: 'Belgrave Express',
      originStation: flinders,
      destinationStation: southernCross,
      stops: [
        ServiceStop(
          station: flinders,
          departureTime: now,
          platform: 'Platform 1',
          stopSequence: 1,
        ),
        ServiceStop(
          station: southernCross,
          arrivalTime: now.add(const Duration(minutes: 4)),
          platform: 'Platform 9',
          stopSequence: 2,
        ),
      ],
    );
  }
}
