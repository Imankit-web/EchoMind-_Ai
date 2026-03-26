import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<List<String>> generateOptions(String question, String apiKey, {String? contextQ, String? contextA, List<String>? currentBuffer}) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_GROQ_API_KEY') {
      return []; 
    }

    final isProgressive = currentBuffer != null && currentBuffer.isNotEmpty;

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
              'content': isProgressive 
                ? 'The user is responding to: "$question". They have already selected: "${currentBuffer.join(" ")}".\n'
                  'Suggest 3-4 logical, very short NEXT words (1-2 words each) to continue this sentence naturally.\n'
                  'Return ONLY a JSON array of strings: ["next1", "next2", "next3"].'
                : 'You are assisting a paralyzed patient in a hospital.\n'
                  '${(contextQ != null && contextQ.isNotEmpty && contextA != null && contextA.isNotEmpty) ? 'Context from previous interaction - Doctor asked: "$contextQ", Patient answered: "$contextA".\nIf the NEW question is a short follow-up (e.g., "Where?", "Is it severe?", "What about that?"), use this context to understand what is being asked and generate highly specific contextual options for the NEW question.\n' : ''}'
                  'Generate 3-4 very short and simple answer options (1-2 words each) to the doctor\'s NEW question.\n'
                  'Keep answers easy to read quickly.\n'
                  'Detect the language and SCRIPT of the doctor\'s question and respond ONLY in that same language and script.\n'
                  'Return ONLY a JSON array of strings: ["option1", "option2", "option3"].'
            },
            {'role': 'user', 'content': isProgressive ? 'Selected so far: "${currentBuffer.join(" ")}". Next words?' : 'Incoming Question: "$question"'}
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
