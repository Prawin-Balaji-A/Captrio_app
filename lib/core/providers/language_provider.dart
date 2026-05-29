import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class LanguageProvider extends ChangeNotifier {
  String _selectedLanguage = AppConstants.supportedLanguages.first;

  String get selectedLanguage => _selectedLanguage;

  String get languageCode =>
      AppConstants.languageCodes[_selectedLanguage] ?? 'en';

  void setLanguage(String language) {
    if (_selectedLanguage == language) return;
    _selectedLanguage = language;
    notifyListeners();
  }

  // Called after login — set user's preferred language
  void initFromUser(String preferredLanguage) {
    _selectedLanguage = preferredLanguage;
    notifyListeners();
  }
}