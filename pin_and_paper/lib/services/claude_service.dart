import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/task_suggestion.dart';

class ClaudeService {
  final String _baseUrl = 'https://api.anthropic.com/v1';
  final String _model = 'claude-3-5-sonnet-20241022';  // Latest Sonnet
  final Uuid _uuid = const Uuid();

  // Estimate API cost before sending
  // Claude pricing (as of 2024): ~$3 per million input tokens, ~$15 per million output tokens
  // Average brain dump: ~500 tokens input, ~500 tokens output = ~$0.01
  Future<double> estimateCost(String text) async {
    final inputTokens = _estimateTokens(text);
    final outputTokens = 500; // Conservative estimate for JSON response

    // Pricing for Claude 3.5 Sonnet
    final inputCost = (inputTokens / 1000000) * 3.0;   // $3/MTok
    final outputCost = (outputTokens / 1000000) * 15.0; // $15/MTok

    return inputCost + outputCost;
  }

  // Extract tasks from brain dump
  Future<List<TaskSuggestion>> extractTasks(String dump, String apiKey) async {
    final prompt = _buildPrompt(dump);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 2000,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      } else {
        throw ClaudeApiException(
          'API request failed: ${response.statusCode} ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } catch (e) {
      throw ClaudeApiException('Network error: $e', 0);
    }
  }

  // Build structured prompt for Claude
  String _buildPrompt(String dump) {
    return '''
You are helping someone with ADHD organize their thoughts. They've dumped chaotic text below. Your task is to extract clear, actionable tasks.

RULES:
1. Extract ONLY actionable items (things they need to DO)
2. Each task should be a single, specific action
3. Keep task titles concise (max 50 characters)
4. If context is important, put it in "notes"
5. Don't add tasks they didn't mention
6. Return ONLY valid JSON (no markdown, no explanation)

OUTPUT FORMAT (JSON array):
[
  {"title": "Call dentist for appointment", "notes": "Mentioned tooth pain"},
  {"title": "Buy groceries", "notes": "Needs: milk, eggs, bread"},
  {"title": "Reply to Sarah's email", "notes": null}
]

USER'S BRAIN DUMP:
$dump

TASKS (JSON only):''';
  }

  // Parse Claude's JSON response into TaskSuggestion objects
  List<TaskSuggestion> _parseResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      final content = decoded['content'][0]['text'] as String;

      // Claude should return pure JSON, but might wrap it
      final jsonString = _extractJson(content);
      final List<dynamic> taskList = jsonDecode(jsonString);

      return taskList.map((json) {
        return TaskSuggestion.fromJson(
          json as Map<String, dynamic>,
          _uuid.v4(), // Generate ID for suggestion
        );
      }).toList();
    } catch (e) {
      throw ClaudeApiException('Failed to parse response: $e', 0);
    }
  }

  // Extract JSON array from potential markdown wrapper
  String _extractJson(String text) {
    // Remove markdown code blocks if present
    final jsonMatch = RegExp(r'```(?:json)?\s*(\[.*?\])\s*```', dotAll: true)
        .firstMatch(text);
    if (jsonMatch != null) {
      return jsonMatch.group(1)!;
    }

    // Look for JSON array
    final arrayMatch = RegExp(r'\[.*?\]', dotAll: true).firstMatch(text);
    if (arrayMatch != null) {
      return arrayMatch.group(0)!;
    }

    return text.trim();
  }

  // Estimate tokens (rough approximation: 1 token ≈ 4 characters)
  int _estimateTokens(String text) {
    return (text.length / 4).ceil();
  }
}

// Custom exception for Claude API errors
class ClaudeApiException implements Exception {
  final String message;
  final int statusCode;

  ClaudeApiException(this.message, this.statusCode);

  @override
  String toString() => 'ClaudeApiException: $message';
}
