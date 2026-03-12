import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyDefaultShopId = 'default_shop_id';
  static const String _keyDefaultShopName = 'default_shop_name';

  static Future<void> setDefaultShop(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultShopId, id);
    await prefs.setString(_keyDefaultShopName, name);
  }

  static Future<Map<String, String?>?> getDefaultShop() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyDefaultShopId);
    final name = prefs.getString(_keyDefaultShopName);
    
    if (id == null) return null;
    return {'id': id, 'name': name};
  }

  static Future<void> clearDefaultShop() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDefaultShopId);
    await prefs.remove(_keyDefaultShopName);
  }
}
