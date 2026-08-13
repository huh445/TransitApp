import 'package:flutter/material.dart';
import 'src/data/repositories/gtfs_repository.dart';
import 'src/presentation/screens/home_screen.dart';
import 'src/services/ptv_rt_service.dart';
import 'src/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvService.loadEnv();
  runApp(const TransitApp());
}

class TransitApp extends StatelessWidget {
  final IGtfsRepository? repository;
  final PtvRealtimeService? ptvService;

  const TransitApp({super.key, this.repository, this.ptvService});

  @override
  Widget build(BuildContext context) {
    final defaultRepository = PtvGtfsRepository(
      masterZipUrl: Uri.parse(
        'https://gtfs.ptv.vic.gov.au/gtfs-outbound/gtfs.zip',
      ),
    );

    return MaterialApp(
      title: 'Melbourne Transit Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: HomeScreen(
        repository: repository ?? defaultRepository,
        ptvService: ptvService,
      ),
    );
  }
}
