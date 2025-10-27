import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  bool _hasApiKey = false;
  bool _isLoading = true;
  String? _errorMessage;

  bool get hasApiKey => _hasApiKey;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize - check if API key exists
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _hasApiKey = await _settingsService.hasApiKey();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to check API key: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Save API key
  Future<void> saveApiKey(String apiKey) async {
    try {
      await _settingsService.saveApiKey(apiKey);
      _hasApiKey = true;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save API key: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Delete API key
  Future<void> deleteApiKey() async {
    try {
      await _settingsService.deleteApiKey();
      _hasApiKey = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete API key: $e';
      notifyListeners();
    }
  }

  // Get API key (for API calls)
  Future<String?> getApiKey() async {
    return await _settingsService.getApiKey();
  }
}
