import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Manages a lightweight, anonymous local player identity.
///
/// A stable userId is generated once and stored on the device so scores can be
/// attributed without forcing sign-up. The player can set a display name.
class PlayerService {
  static const _keyUserId = 'player_user_id';
  static const _keyDisplayName = 'player_display_name';

  String _userId = '';
  String _displayName = 'Anonymous';

  String get userId => _userId;
  String get displayName => _displayName;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_keyUserId) ?? '';
    if (_userId.isEmpty) {
      _userId = const Uuid().v4();
      await prefs.setString(_keyUserId, _userId);
    }
    _displayName = prefs.getString(_keyDisplayName) ?? 'Anonymous';
  }

  Future<void> setDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _displayName = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, trimmed);
  }
}
