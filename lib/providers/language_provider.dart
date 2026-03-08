import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/strings.dart';

class LanguageProvider extends ChangeNotifier {
  bool _isAmharic = true; // default to Amharic
  static const _prefKey = 'lang_amharic';

  bool get isAmharic => _isAmharic;
  AppStrings get s => _isAmharic ? AppStrings.am : AppStrings.en;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isAmharic = prefs.getBool(_prefKey) ?? true;
    notifyListeners();
  }

  Future<void> setAmharic(bool value) async {
    if (_isAmharic == value) return;
    _isAmharic = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  void toggle() => setAmharic(!_isAmharic);
}
