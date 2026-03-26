import re
import os

path = r'd:\coding\Echo Ai 2.0\lib\main.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern to find the mess between _initTts and _formatSpeech
# It matches from the first occurrence of _detectLanguage through any number of intermediate blocks until it finds the final _speak signature
pattern = r'String _detectLanguage\(String text\) \{[\s\S]*?Future<void> _speak\(String text\) async \{'

replacement = r'''String _detectLanguage(String text) {
    // Basic detection for Indian languages based on character ranges
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0x0900 && code <= 0x097F) return "hi-IN"; // Devanagari (Hindi)
      if (code >= 0x0980 && code <= 0x09FF) return "bn-IN"; // Bengali script
    }
    // Default to en-US for natural English pronunciation, as requested by user
    return "en-US";
  }

  String _buildFinalSentence() {
    if (_responseBuffer.isEmpty) return "";
    
    String prefix = "";
    List<String> remaining = List.from(_responseBuffer);
    
    final first = remaining.first.toLowerCase();
    // Support common Yes/No in English/Hindi/Bengali
    if (first == "yes" || first == "no" || first == "ha" || first == "na" || first == "haan") {
      prefix = "${remaining.removeAt(0)}, ";
    }
    
    if (remaining.isEmpty) return prefix.replaceAll(", ", "");

    final mainPart = remaining.join(" ").toLowerCase();
    
    // Natural language heuristics based on common clinical keywords
    if (mainPart.contains("pain") && mainPart.contains("chest")) return "${prefix}I have pain in my chest";
    if (mainPart.contains("pain") && mainPart.contains("head")) return "${prefix}I have pain in my head";
    if (mainPart.contains("pain")) return "${prefix}I am in pain";
    if (mainPart.contains("breathing") || mainPart.contains("difficulty")) return "${prefix}I am having difficulty breathing";
    if (mainPart.contains("water")) return "${prefix}I need some water";
    if (mainPart.contains("food") || mainPart.contains("hungry")) return "${prefix}I am hungry";
    if (mainPart.contains("help")) return "${prefix}Please help me";
    if (mainPart.contains("fine") || mainPart.contains("good") || mainPart.contains("theek")) return "${prefix}I am feeling fine";
    
    return prefix + remaining.join(" ");
  }

  Future<void> _speak(String text) async {'''

new_content = re.sub(pattern, replacement, content)

# Also fix the corrupted arrow symbol (â†’) which commonly happens in UTF-8 -> CP1252 mishandling
new_content = new_content.replace('â†’', '->')

if new_content != content:
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Successfully cleaned up lib/main.dart")
else:
    print("No changes needed or pattern not found")
