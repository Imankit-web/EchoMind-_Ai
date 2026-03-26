$path = "d:\coding\Echo Ai 2.0\lib\main.dart"
$content = Get-Content -Path $path -Raw

# 1. Add _responseBuffer state variable
$content = $content -replace '(late PatientIntent _intent;)', '$1
  final List<String> _responseBuffer = [];'

# 2. Update _setupBlinkListeners to support buffering and Long Blink
$oldSelection = '(?s)_blinkService\.selectionStream\.listen\(\(index\) \{.*?\}\);'
$newSelection = @'
_blinkService.selectionStream.listen((index) {
      if (mounted && _useBlink && _canBlink && !widget.isDemo) {
        if (index < _options.length) {
          setState(() {
            _responseBuffer.add(_options[index]);
            // Give visual feedback via pulse
            _pulse = true;
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _pulse = false);
          });
        }
      }
    });

    _blinkService.longBlinkStream.listen((_) {
      if (mounted && _useBlink && _canBlink && !widget.isDemo && _responseBuffer.isNotEmpty) {
        final sentence = _buildFinalSentence();
        _speak(sentence);
      }
    });
'@
$content = [regex]::Replace($content, $oldSelection, $newSelection)

# 3. Add _buildFinalSentence and keep _detectLanguage
$oldDetect = '(?s)String _detectLanguage\(String text\) \{.*?\}'
$newDetectAndBuild = @'
String _detectLanguage(String text) {
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
'@
$content = [regex]::Replace($content, $oldDetect, $newDetectAndBuild)

# 4. Update UI: Sentence Preview and Instructions
$oldAnswerUI = '(?s)if \(_selectedAnswer\.isNotEmpty\).*?fontSize\: 18\)\),.*?\),'
$newAnswerUI = @'
if (_responseBuffer.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            const Text("PREVIEW:", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Text(
                              _responseBuffer.join(" → "), 
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 28)
                            ),
                          ],
                        ),
                      ),
'@
$content = [regex]::Replace($content, $oldAnswerUI, $newAnswerUI)

$oldInstruct = 'const Text\("1 blink\: Option 1 \| 2 blinks\: Option 2 \| 3 blinks\: Option 3"'
$newInstruct = 'const Text("1-3 blinks: Select word | Long Blink: CONFIRM & SPEAK"'
$content = $content -replace $oldInstruct, $newInstruct

Set-Content -Path $path -Value $content -Encoding utf8
