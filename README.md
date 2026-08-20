# Interchange

Interchange is a Flutter transit app for Melbourne (PTV) that combines live API data with offline GTFS data to help riders plan and track trips.

## Highlights

- Real-time train departures with fallback to local GTFS timetable data
- Live ride tracking with station detection and progress updates
- Connection feasibility advisor for key interchange stations
- Disruption and alert visibility for active lines and saved stations
- Favorites and fast station search

## Tech Stack

- Flutter + Dart
- PTV Timetable API v3
- GTFS static feed parsing and local caching

## Project Structure

```text
lib/
├── main.dart
└── src/
    ├── data/
    ├── domain/
    ├── presentation/
    ├── services/
    └── theme/
```

## Getting Started

### Prerequisites

- Flutter SDK (`>=3.12.2`)
- Dart SDK (`^3.12.2`)
- iOS simulator, Android emulator, or physical device
- PTV Developer ID and API Key

### Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/huh4k/Interchange.git
   cd Interchange
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Create a `.env` file in the project root:

   ```env
   PTV_USER_ID=your_ptv_dev_id
   PTV_API_KEY=your_ptv_api_key
   PTV_BASE_URL=https://timetableapi.ptv.vic.gov.au
   ```

4. Run the app:

   ```bash
   flutter run
   ```

## Testing

Run the test suite:

```bash
flutter test
```

## License

This project is licensed under the [MIT License](LICENSE).
