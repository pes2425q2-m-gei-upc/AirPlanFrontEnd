// lib/services/sync_preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class SyncPreferencesService {
  static const String _syncKey = 'google_calendar_sync_enabled';

  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncKey, enabled);
  }

  Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncKey) ?? false;
  }
}