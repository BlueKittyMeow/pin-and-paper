import 'package:http/http.dart' as http;
import 'dart:convert';
import 'secure_storage_service.dart';

class SettingsService {
  final SecureStorageService _storage = SecureStorageService.instance;

  // Validate API key format (simple non-empty check)
  // Don't hardcode prefix/length - Anthropic could change formats
  bool isValidApiKey(String key) {
    return key.trim().isNotEmpty && key.trim().length > 10;
  }

  // Test API key with a lightweight Claude API call
  // Returns (success, errorMessage)
  Future<(bool, String?)> testApiKey(String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-3-5-sonnet-20241022',
          'max_tokens': 10, // Minimal tokens to save cost
          'messages': [
            {
              'role': 'user',
              'content': 'Hi', // Minimal test message
            }
          ],
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return (true, null); // Success!
      } else if (response.statusCode == 401) {
        return (false, 'Invalid API key');
      } else if (response.statusCode == 429) {
        // IMPLEMENTATION REMINDER FIX: 429 proves key is valid!
        // Show success (green checkmark) with warning message
        return (true, 'Connected (rate limited - try again in a moment)');
      } else {
        return (false, 'API error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return (false, 'Connection timeout - check your internet');
      }
      return (false, 'Connection error: $e');
    }
  }

  // Save API key (no brittle format validation)
  Future<void> saveApiKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (!isValidApiKey(trimmed)) {
      throw ArgumentError('API key cannot be empty');
    }
    await _storage.saveClaudeApiKey(trimmed);
  }

  // Get API key
  Future<String?> getApiKey() async {
    return await _storage.getClaudeApiKey();
  }

  // Check if API key is configured
  Future<bool> hasApiKey() async {
    return await _storage.hasClaudeApiKey();
  }

  // Delete API key
  Future<void> deleteApiKey() async {
    await _storage.deleteClaudeApiKey();
  }
}
