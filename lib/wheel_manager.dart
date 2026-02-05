import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'wheel_config.dart';

class WheelManager {
  static const String _key = 'saved_wheels';

  Future<List<WheelConfig>> loadWheels() async {
    final prefs = await SharedPreferences.getInstance();
    final String? wheelsJson = prefs.getString(_key);

    if (wheelsJson == null) {
      return [];
    }

    try {
      final List<dynamic> wheelsList = json.decode(wheelsJson) as List<dynamic>;
      return wheelsList
          .map((item) => WheelConfig.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveWheels(List<WheelConfig> wheels) async {
    final prefs = await SharedPreferences.getInstance();
    final wheelsJson = json.encode(wheels.map((w) => w.toJson()).toList());
    await prefs.setString(_key, wheelsJson);
  }

  Future<void> saveWheel(WheelConfig wheel) async {
    final wheels = await loadWheels();
    final existingIndex = wheels.indexWhere((w) => w.id == wheel.id);

    if (existingIndex >= 0) {
      wheels[existingIndex] = wheel;
    } else {
      wheels.add(wheel);
    }

    await saveWheels(wheels);
  }

  Future<void> deleteWheel(String id) async {
    final wheels = await loadWheels();
    wheels.removeWhere((w) => w.id == id);
    await saveWheels(wheels);
  }
}
