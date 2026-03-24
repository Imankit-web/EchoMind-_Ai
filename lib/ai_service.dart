import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart' show AppLanguage;

class AIService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<List<String>> generateOptions(String question, AppLanguage language, String apiKey) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_GROQ_API_KEY') {
      return []; 
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a medical assistant for a patient who cannot speak. '
                  'Generate 3 very short, natural, and simple answer options (max 5 words each) '
                  'that a patient would use to respond to the doctor question. '
                  'The response MUST be in ${language.name}. '
                  'Return ONLY a JSON array of strings: ["option1", "option2", "option3"].'
            },
            {'role': 'user', 'content': 'Doctor asks: "$question"'}
          ],
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        final match = RegExp(r'\[.*\]').firstMatch(content);
        if (match != null) {
          final List<dynamic> options = jsonDecode(match.group(0)!);
          return options.map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
