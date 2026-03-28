import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class GoogleTTSService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Future<bool> speak(String text, String langCode, String apiKey) async {
    if (apiKey.isEmpty || text.isEmpty) return false;

    // Map language code to Neural2 voices
    String voiceName;
    if (langCode == 'hi-IN') {
      voiceName = 'hi-IN-Neural2-A';
    } else {
      voiceName = 'en-US-Neural2-F';
    }

    try {
      final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {
            'languageCode': langCode,
            'name': voiceName,
          },
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': langCode == 'hi-IN' ? 0.45 : 0.5,
            'pitch': 0.0,
          },
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final audioContent = data['audioContent'] as String;
        final audioBytes = base64Decode(audioContent);

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/tts_output.mp3');
        await tempFile.writeAsBytes(audioBytes);

        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(tempFile.path));
        
        return true;
      } else {
        debugPrint('Google TTS API Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Google TTS Exception: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    await _audioPlayer.stop();
  }
}
