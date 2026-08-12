import 'package:flutter/material.dart';
import 'src/features/home/home_screen.dart';
import 'src/services/gtfs_parser.dart';
import 'src/services/ptv_rt_service.dart';
import 'src/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvService.loadEnv();

  final ptvGtfsRepository = PtvGtfsRepository(
    masterZipUrl: Uri.parse('https://data.ptv.vic.gov.au/downloads/gtfs.zip'),
  );

  runApp(TransitApp(repository: ptvGtfsRepository));
}

class TransitApp extends StatelessWidget {
  final IGtfsRepository repository;

  const TransitApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melbourne Transit Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: HomeScreen(repository: repository),
    );
  }
}
