import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  final String _apiUrl = 'https://router.huggingface.co/v1/chat/completions';
  final String _hfModel = 'Qwen/Qwen2.5-72B-Instruct';
  bool _isInitialized = false;
  late final String _apiKey;

  AiService() {
    final apiKey = dotenv.env['HUGGINGFACE_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      _apiKey = apiKey;
      _isInitialized = true;
    } else {
      print('WARNING: HUGGINGFACE_API_KEY is not found in .env');
    }
  }

  /// Search movies using abstract user queries (Mood Search)
  Future<List<String>> searchMoviesByMood(String userQuery) async {
    if (!_isInitialized) {
      print('AiService not initialized. Cannot perform mood search.');
      return [];
    }

    if (userQuery.trim().isEmpty) return [];

    final prompt =
        '''
You are a brilliant movie expert. The user is searching for movies based on this query in Russian: "$userQuery"

YOUR RULES:
1. Understand the INTENT. If they ask for movies like "Very Scary Movie" (Очень страшное кино), that is a PARODY COMEDY, not a horror film! Recommend other parody comedies, NOT horror movies.
2. Do not get confused by literal words. Look at the genre and vibe.
3. Reply with ONLY a raw JSON array of 10 movie titles in their ORIGINAL LANGUAGE (usually English). No translations.
4. No extra words, comments, markdown formatting. Only JSON.

Example of ideal response:
["Inception", "Dune", "Interstellar"]
''';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _hfModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You strictly reply with JSON arrays of strings. No extra text.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String jsonString = data['choices'][0]['message']['content']
            .toString()
            .trim();

        // Clean up markdown block if the model included it
        final regex = RegExp(r'\[.*\]', dotAll: true);
        final match = regex.firstMatch(jsonString);

        if (match != null) {
          jsonString = match.group(0)!;
        } else {
          print('Warning: No JSON array found. Raw output: $jsonString');
          return [];
        }

        try {
          final List<dynamic> decoded = jsonDecode(jsonString);
          return decoded.cast<String>();
        } catch (e) {
          print('Error decoding JSON from HuggingFace: $e\nRaw: $jsonString');
          return [];
        }
      } else {
        print(
          'HuggingFace API Error: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('Exception in searchMoviesByMood: $e');
      return [];
    }
  }
}
