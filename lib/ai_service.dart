import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<List<String>> generateOptions(String question, String apiKey) async {
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
              'content': 'You are assisting a paralyzed patient in a hospital. '
                  'Generate 3 very short and simple answer options (1-3 words each) to a doctor\'s question. '
                  'No long sentences. Keep answers easy to read quickly. '
                  'Detect the language and SCRIPT of the doctor\'s question and respond ONLY in that same language and script. '
                  'For example, if the doctor asks in Hindi (Devanagari), respond in Hindi (Devanagari). '
                  'If the doctor asks in Bengali (Bengali script), respond in Bengali (Bengali script). '
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
