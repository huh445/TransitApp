# Melbourne Transit Pulse

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-49%20Passed-success?style=for-the-badge&logo=checkmarx&logoColor=white)]()

A high-performance, real-time public transit companion for **Melbourne, Victoria (PTV)** built with **Flutter**.

Melbourne Transit Pulse combines the **official PTV Timetable API v3** with an **offline-first GTFS static timetable parser** and **intelligent connection advisor** to deliver live suburban train departures, GPS on-board ride tracking, transfer predictions, and network disruption alerts.

---

## Features

- **Live Real-Time Departures**  
  Real-time departure timetables for all Melbourne metropolitan train stations fetched via PTV API v3 with automatic fallback to local GTFS static feeds.
- **On-Board Live Ride Tracking**  
  Active journey mode powered by GPS positioning: automatically detects the current station, upcoming stops, countdown to destination, and remaining journey timeline.
- **Smart Connection Advisor**  
  Predicts connection feasibility (*Comfortable*, *Tight*, *Impossible*) at key Melbourne interchange stations (e.g. Flinders St, Southern Cross, Richmond, North Melbourne, Footscray, Caulfield, Clifton Hill). Automatically suggests backup departures when transfer margins are tight (<= 4 minutes).
- **Live Disruptions & Alerts**  
  Direct feed of PTV network disruptions, filtered dynamically to your favorite stations, active lines, or the entire metropolitan network.
- **Favorites & Quick Access**  
  Save frequently used stations and trips with offline persistence using local caching.
- **Instant Station Search**  
  Fuzzy-search across all Melbourne stations and interchanges with normalized names and PTV stop ID resolution.
- **Modern Material 3 Interface**  
  Sleek dark and light themes with official PTV color coding (Metro Train Blue, Tram Green, V/Line Purple, Bus Orange), smooth animations, and responsive layouts.

---

## Architecture & Project Structure

The project follows Clean Architecture and Domain-Driven Design (DDD) principles:

```
lib/
├── main.dart                          # Application entry point & theme initialization
└── src/
    ├── data/
    │   ├── datasources/
    │   │   └── gtfs_index_engine.dart # In-memory GTFS indexing engine
    │   └── repositories/
    │       └── gtfs_repository.dart   # GTFS repository interface and implementation
    ├── domain/
    │   ├── entities/                  # Domain entities
    │   │   ├── live_connection.dart   # Transfer feasibility & connection models
    │   │   ├── service.dart           # Service stops & alerts
    │   │   ├── station.dart           # Station & interchange entities
    │   │   ├── transit_route.dart     # Route metadata & line definitions
    │   │   └── trips.dart             # Trip & scheduled departure entities
    │   └── value_objects/             # Strongly typed enums and value objects
    │       ├── ptv_mode.dart          # Metro, Tram, Bus, V/Line, Ferry modes
    │       ├── service_status.dart    # On-time, delayed, disrupted status
    │       ├── transfer_feasibility.dart # Connection feasibility scoring
    │       └── transit_type.dart      # Express, limited express, stopping all
    ├── presentation/
    │   ├── screens/
    │   │   ├── home_screen.dart       # Main departures & navigation hub
    │   │   └── disruptions_screen.dart# Service disruptions & line status screen
    │   ├── state/
    │   │   └── transit_view_model.dart# Reactive state management (ChangeNotifier)
    │   └── widgets/                   # Modular UI components
    │       ├── alert_banner_widget.dart
    │       ├── app_header_widget.dart
    │       ├── empty_state_widget.dart
    │       ├── live_ride_sheet.dart   # Modal bottom sheet for live on-board tracking
    │       ├── mode_filter_bar.dart   # Mode selector chips
    │       ├── station_search_sheet.dart
    │       ├── station_selector_card.dart
    │       ├── trip_card_widget.dart  # Departure card with status badges
    │       └── trip_details_sheet.dart# Stopping pattern & timeline view
    ├── services/
    │   ├── connection_advisor_service.dart # Real-time transfer feasibility engine
    │   ├── connection_service.dart    # Interchange station directory & rules
    │   ├── favorite_service.dart      # SharedPreferences persistence
    │   ├── gtfs_parser.dart           # GTFS CSV & text file parser
    │   ├── location_service.dart      # Geolocator & GPS distance calculation
    │   ├── melbourne_gtfs_service.dart# Station loader, streaming downloader & disk cache
    │   └── ptv_rt_service.dart        # PTV API v3 client with HMAC-SHA1 signing
    └── theme/
        └── app_theme.dart             # Material 3 colors, typography & dark/light themes
```

---

## Getting Started

### Prerequisites

- **Flutter SDK**: `>= 3.12.2` ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK**: `^3.12.2`
- An iOS simulator / Android emulator or physical mobile device
- (Optional) **PTV API Key & Developer ID** ([Register for PTV API](https://www.ptv.vic.gov.au/footer/data-and-reporting/datasets/ptv-timetable-api/))

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/huh4k/TransitApp.git
   cd TransitApp
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**

   Create a `.env` file in the root directory (or edit the existing one):
   ```env
   PTV_USER_ID=your_ptv_dev_id
   PTV_API_KEY=your_ptv_api_key
   PTV_BASE_URL=https://timetableapi.ptv.vic.gov.au
   ```

   > Note: The app includes working default credentials for development, but you can configure your own developer keys.

4. **Run the application:**
   ```bash
   flutter run
   ```

---

## Testing

The repository contains a comprehensive suite of unit and widget tests covering GTFS parsing, PTV API signature generation, transfer feasibility algorithms, state management, and UI components:

```bash
flutter test
```

To run a specific test file:
```bash
flutter test test/connection_advisor_test.dart
flutter test test/melbourne_gtfs_test.dart
flutter test test/transit_view_model_test.dart
```

---

## Core Technologies & Libraries

| Package | Purpose |
|---|---|
| [`http`](https://pub.dev/packages/http) | Network requests and streaming data feeds |
| [`crypto`](https://pub.dev/packages/crypto) | HMAC-SHA1 cryptographic signature generation for PTV API v3 |
| [`geolocator`](https://pub.dev/packages/geolocator) | GPS position tracking and nearest station calculation |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Local persistent storage for favorite stations and trips |
| [`path_provider`](https://pub.dev/packages/path_provider) | Device file storage for caching GTFS static feeds |
| [`archive`](https://pub.dev/packages/archive) | Extraction of compressed GTFS timetable archives |
| [`flutter_lints`](https://pub.dev/packages/flutter_lints) | Recommended static analysis and code style rules |

---

## Key Interchange Stations Supported

Melbourne Transit Pulse includes specialized transfer and connection rules for major metropolitan interchange hubs:

- **City Loop**: Flinders Street (`FSS`), Southern Cross (`SSS`), Melbourne Central (`MCE`), Parliament (`PAR`), Flagstaff (`FGS`)
- **Inner City**: Richmond (`RMD`), North Melbourne (`NME`), South Yarra (`SYR`), Footscray (`FSY`), Clifton Hill (`CHL`), Burnley (`BLY`), Caulfield (`CFD`)
- **Junctions & Outer Hubs**: Camberwell, Ringwood, Dandenong, Frankston, Newport, Sunshine, Watergardens, Broadmeadows, Essendon

---

## License

This project is licensed under the [MIT License](LICENSE).
