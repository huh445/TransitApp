import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/station.dart';

class FavoriteService {
  static const String _favoritesKey = 'favorite_stations';

  Future<List<Station>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_favoritesKey);
    
    if (favoritesJson == null || favoritesJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decodedList = json.decode(favoritesJson);
      return decodedList.map((item) => Station.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFavorites(List<Station> stations) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> mapList = stations.map((s) => s.toMap()).toList();
    await prefs.setString(_favoritesKey, json.encode(mapList));
  }
}
