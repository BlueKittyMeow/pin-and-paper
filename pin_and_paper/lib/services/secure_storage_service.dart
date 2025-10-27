import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._init();
  SecureStorageService._init();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,  // Use EncryptedSharedPreferences
    ),
  );

  // Keys
  static const String _claudeApiKeyKey = 'claude_api_key';

  // Save Claude API key
  Future<void> saveClaudeApiKey(String apiKey) async {
    await _storage.write(key: _claudeApiKeyKey, value: apiKey);
  }

  // Get Claude API key
  Future<String?> getClaudeApiKey() async {
    return await _storage.read(key: _claudeApiKeyKey);
  }

  // Delete Claude API key
  Future<void> deleteClaudeApiKey() async {
    await _storage.delete(key: _claudeApiKeyKey);
  }

  // Check if API key exists
  Future<bool> hasClaudeApiKey() async {
    final key = await getClaudeApiKey();
    return key != null && key.isNotEmpty;
  }
}
