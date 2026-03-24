import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'blink_service.dart';
import 'ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings().init();
  runApp(const EchoMindAiApp());
}

enum AppLanguage {
  en('English', 'en-IN'),
  hi('Hindi', 'hi-IN'),
  bn('Bengali', 'bn-IN');

  final String name;
  final String code;
  const AppLanguage(this.name, this.code);
}

final Map<String, Map<AppLanguage, String>> translations = {
  'Yes': {AppLanguage.en: 'Yes', AppLanguage.hi: 'हाँ', AppLanguage.bn: 'হ্যাঁ'},
  'No': {AppLanguage.en: 'No', AppLanguage.hi: 'नहीं', AppLanguage.bn: 'না'},
  'Severe': {AppLanguage.en: 'Severe', AppLanguage.hi: 'গম্ভীর', AppLanguage.bn: 'গুরুতর'},
  'Good': {AppLanguage.en: 'Good', AppLanguage.hi: 'अच्छा', AppLanguage.bn: 'ভালো'},
  'Okay': {AppLanguage.en: 'Okay', AppLanguage.hi: 'ঠিক है', AppLanguage.bn: 'ঠিক আছে'},
  'Bad': {AppLanguage.en: 'Bad', AppLanguage.hi: 'খারাৰ', AppLanguage.bn: 'খারাপ'},
  'Urgent': {AppLanguage.en: 'Urgent', AppLanguage.hi: 'তৎকাল', AppLanguage.bn: 'জরুরী'},
  "I don't know": {AppLanguage.en: "I don't know", AppLanguage.hi: 'पता नहीं', AppLanguage.bn: 'জানিনা'},
  'Food/Water': {AppLanguage.en: 'Food/Water', AppLanguage.hi: 'खाना/पानी', AppLanguage.bn: 'খাবার/জল'},
};

final Map<String, Map<AppLanguage, String>> enhancedSentences = {
  'Yes': {AppLanguage.en: 'Yes, I am.', AppLanguage.hi: 'हाँ, मैं हूँ।', AppLanguage.bn: 'হ্যাঁ, আমি আছি।'},
  'No': {AppLanguage.en: 'No, I am not.', AppLanguage.hi: 'नहीं, मैं नहीं हूँ।', AppLanguage.bn: 'না, আমি নই।'},
  'Severe': {AppLanguage.en: 'I am in severe pain.', AppLanguage.hi: 'मुझे बहुत दर्द हो रहा है।', AppLanguage.bn: 'আমার খুব ব্যথা করছে।'},
  'Good': {AppLanguage.en: 'I am feeling good.', AppLanguage.hi: 'मैं अच्छा महसूस कर रहा हूँ।', AppLanguage.bn: 'আমি ভালো বোধ করছি।'},
  'Okay': {AppLanguage.en: 'I am okay right now.', AppLanguage.hi: 'मैं अभी ठीक हूँ।', AppLanguage.bn: 'আমি এখন ঠিক আছি।'},
  'Bad': {AppLanguage.en: 'I am not feeling well.', AppLanguage.hi: 'मेरी तबीयत ठीक नहीं है।', AppLanguage.bn: 'আমার শরীর ভালো নেই।'},
  'Urgent': {AppLanguage.en: 'Please help, it is urgent.', AppLanguage.hi: 'कृपया मदद करें, यह तत्काल है।', AppLanguage.bn: 'দয়া করে সাহায্য করুন, এটা জরুরী।'},
  "I don't know": {AppLanguage.en: "I don't know the answer.", AppLanguage.hi: 'मुझे इसका जवाब नहीं पता।', AppLanguage.bn: 'আমি এর উত্তর জানি না।'},
  'Food/Water': {AppLanguage.en: 'I need food or water.', AppLanguage.hi: 'मुझे खाने या पानी की जरूरत है।', AppLanguage.bn: 'আমার খাবার বা জলের প্রয়োজন।'},
};

enum PatientIntent {
  condition('Condition', ['Good', 'Okay', 'Bad']),
  pain('Pain', ['Yes', 'No', 'Severe']),
  need('Need', ['Yes', 'No', 'Food/Water']),
  emergency('Emergency', ['Yes', 'No', 'Urgent']),
  unknown('General', ['Yes', 'No', "I don't know"]);

  final String label;
  final List<String> optionKeys;
  const PatientIntent(this.label, this.optionKeys);

  static PatientIntent detect(String question) {
    final q = question.toLowerCase();
    if (q.contains('how are you') || q.contains('feeling') || q.contains('condition')) return condition;
    if (q.contains('pain') || q.contains('hurt') || q.contains('ache')) return pain;
    if (q.contains('water') || q.contains('drink') || q.contains('eat') || q.contains('food')) return need;
    if (q.contains('breathing') || q.contains('problem') || q.contains('emergency') || q.contains('danger')) return emergency;
    return unknown;
  }
}

class AppSettings {
  String aiApiKey = '';
  double speechRate = 0.45;
  String userName = '';
  bool isFirstRun = true;
  AppLanguage defaultLanguage = AppLanguage.en;

  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    aiApiKey = _prefs.getString('aiApiKey') ?? '';
    speechRate = _prefs.getDouble('speechRate') ?? 0.45;
    userName = _prefs.getString('userName') ?? '';
    isFirstRun = _prefs.getBool('isFirstRun') ?? true;
    final langCode = _prefs.getString('defaultLanguage');
    if (langCode != null) {
      defaultLanguage = AppLanguage.values.firstWhere((l) => l.code == langCode, orElse: () => AppLanguage.en);
    }
  }

  Future<void> save() async {
    await _prefs.setString('aiApiKey', aiApiKey);
    await _prefs.setDouble('speechRate', speechRate);
    await _prefs.setString('userName', userName);
    await _prefs.setBool('isFirstRun', isFirstRun);
    await _prefs.setString('defaultLanguage', defaultLanguage.code);
  }
}

class EchoMindAiApp extends StatefulWidget {
  const EchoMindAiApp({super.key});

  @override
  State<EchoMindAiApp> createState() => _EchoMindAiAppState();
}

class _EchoMindAiAppState extends State<EchoMindAiApp> {
  late AppLanguage _language;
  final List<String> _history = [];
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _language = AppSettings().defaultLanguage;
    _showOnboarding = AppSettings().isFirstRun;
  }

  void _addToHistory(String question) {
    setState(() {
      if (!_history.contains(question)) {
        _history.insert(0, question);
        if (_history.length > 10) _history.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echo Ai 2.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1E2D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D2FF),
          secondary: Color(0xFF00FFC2),
          surface: Color(0xFF162D3D),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
          bodyLarge: TextStyle(fontSize: 18, color: Color(0xFF8BA6B8)),
        ),
      ),
      home: _showOnboarding 
        ? OnboardingScreen(onComplete: () {
            setState(() {
              _language = AppSettings().defaultLanguage;
              _showOnboarding = false;
            });
          })
        : DoctorInputScreen(
            language: _language, 
            onLanguageChanged: (l) {
              setState(() => _language = l);
              AppSettings().defaultLanguage = l;
              AppSettings().save();
            },
            history: _history,
            onQuestionSubmitted: _addToHistory,
          ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;

  const GlassCard({super.key, required this.child, this.blur = 10, this.opacity = 0.1, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class SoundWaveMic extends StatefulWidget {
  final bool isListening;

  const SoundWaveMic({super.key, required this.isListening});

  @override
  State<SoundWaveMic> createState() => _SoundWaveMicState();
}

class _SoundWaveMicState extends State<SoundWaveMic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double height = 4.0;
            if (widget.isListening) {
              height = 10.0 + (index * 4 * _controller.value) + (10 * _controller.value);
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: widget.isListening ? const Color(0xFF00FFC2) : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}

class DoctorInputScreen extends StatefulWidget {
  final AppLanguage language;
  final Function(AppLanguage) onLanguageChanged;
  final List<String> history;
  final Function(String) onQuestionSubmitted;

  const DoctorInputScreen({
    super.key, 
    required this.language, 
    required this.onLanguageChanged, 
    required this.history,
    required this.onQuestionSubmitted,
  });

  @override
  State<DoctorInputScreen> createState() => _DoctorInputScreenState();
}

class _DoctorInputScreenState extends State<DoctorInputScreen> {
  final TextEditingController _questionController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isReadyForNext = true;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _initSpeech() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isListening && _questionController.text.trim().isNotEmpty) {
            _handleAutoSubmit();
          } else {
            if (mounted) setState(() => _isListening = false);
            _idleTimer?.cancel();
          }
        }
      },
      onError: (error) {
        if (mounted) setState(() { _isListening = false; _isProcessing = false; });
        _idleTimer?.cancel();
      },
    );
    if (available && mounted) {
      _startListening();
    }
  }

  void _handleAutoSubmit() async {
    _idleTimer?.cancel();
    setState(() { _isProcessing = true; _isReadyForNext = false; _isListening = false; });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      final q = _questionController.text;
      widget.onQuestionSubmitted(q);
      _questionController.clear();
      await _navigateToResponse(q);
      
      if (mounted) {
        setState(() { _isProcessing = false; _isReadyForNext = true; });
        _focusNode.requestFocus();
        _startListening();
      }
    }
  }

  Future<void> _navigateToResponse(String question) async {
    await Navigator.push(
      context, 
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ResponseSelectionScreen(
          question: question, 
          language: widget.language, 
          onLanguageChanged: widget.onLanguageChanged
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      )
    );
  }

  void _startListening() async {
    if (await Permission.microphone.request().isGranted) {
      _idleTimer?.cancel();
      setState(() { _isListening = true; _isProcessing = false; _questionController.clear(); });
      
      await _speechToText.listen(
        onResult: (res) {
          if (mounted) {
            setState(() => _questionController.text = res.recognizedWords);
            if (res.recognizedWords.trim().isNotEmpty) {
              _idleTimer?.cancel();
            }
          }
        }, 
        listenFor: const Duration(seconds: 30), 
        pauseFor: const Duration(seconds: 2)
      );
      
      _idleTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _isListening && _questionController.text.trim().isEmpty) {
          _stopListening();
        }
      });
    } else {
      openAppSettings();
    }
  }

  void _stopListening() async {
    _idleTimer?.cancel();
    await _speechToText.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _copyHistory() {
    final text = widget.history.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session history copied to clipboard')));
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _questionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Doctor Assist Mode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00D2FF))),
              Row(
                children: [
                   AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 8, height: 8, 
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _isProcessing ? Colors.orangeAccent : (_isListening ? const Color(0xFF00FFC2) : const Color(0xFF00FFC2))),
                  ),
                  const SizedBox(width: 8),
                  Text(_isProcessing ? "Processing..." : (_isListening ? "Listening for next question..." : "Ready"), style: TextStyle(fontSize: 12, color: const Color(0xFF00FFC2).withValues(alpha: 0.8))),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF00D2FF)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: PopupMenuButton<AppLanguage>(
                initialValue: widget.language,
                onSelected: widget.onLanguageChanged,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.3))),
                  child: Row(children: [const Icon(Icons.language, size: 16, color: Color(0xFF00D2FF)), const SizedBox(width: 8), Text(widget.language.name, style: const TextStyle(fontSize: 14))]),
                ),
                itemBuilder: (context) => AppLanguage.values.map((l) => PopupMenuItem(value: l, child: Text(l.name))).toList(),
              ),
            )
          ],
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  GlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _questionController,
                          focusNode: _focusNode,
                          maxLines: null,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleAutoSubmit(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Ask medical concern or use mic...",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SoundWaveMic(isListening: _isListening),
                        const SizedBox(height: 16),
                        Semantics(
                          label: _isListening ? 'Stop Listening' : 'Start Listening',
                          child: GestureDetector(
                            onTap: _isListening ? _stopListening : _startListening,
                            child: Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: _isListening ? [const Color(0xFF00FFC2), const Color(0xFF00D2FF)] : [const Color(0xFF162D3D), const Color(0xFF1E3A4D)]),
                                boxShadow: [
                                  if (_isListening) BoxShadow(color: const Color(0xFF00FFC2).withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 4),
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (widget.history.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Recent Queries", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8BA6B8))),
                        TextButton.icon(onPressed: _copyHistory, icon: const Icon(Icons.copy, size: 14), label: const Text("Copy History", style: TextStyle(fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.history.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, i) => GestureDetector(
                          onTap: () => _navigateToResponse(widget.history[i]),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF162D3D),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.15)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: 1)],
                            ),
                            child: Text(widget.history[i], maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: const Color(0xFF0B1E2D).withValues(alpha: 0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00FFC2)),
                    SizedBox(height: 20),
                    Text("Processing Medical Intent...", style: TextStyle(color: Color(0xFF00FFC2), fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController(text: AppSettings().aiApiKey);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Settings"), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("AI Integration", style: TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(labelText: "Groq API Key", hintText: "Enter your API key", border: OutlineInputBorder()),
                    onChanged: (val) => AppSettings().aiApiKey = val,
                  ),
                  const SizedBox(height: 12),
                  const Text("Required for natural response generation.", style: TextStyle(fontSize: 12, color: Colors.white24)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Speech Control", style: TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.bold)),
                  Slider(
                    value: AppSettings().speechRate,
                    min: 0.1, max: 1.0,
                    onChanged: (val) => setState(() => AppSettings().speechRate = val),
                  ),
                  const Text("Adjust voice output speed.", style: TextStyle(fontSize: 12, color: Colors.white24)),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D2FF)), child: const Text("Save and Exit")),
            )
          ],
        ),
      ),
    );
  }
}

class ResponseSelectionScreen extends StatefulWidget {
  final String question;
  final AppLanguage language;
  final Function(AppLanguage) onLanguageChanged;

  const ResponseSelectionScreen({super.key, required this.question, required this.language, required this.onLanguageChanged});

  @override
  State<ResponseSelectionScreen> createState() => _ResponseSelectionScreenState();
}

class _ResponseSelectionScreenState extends State<ResponseSelectionScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  String _selectedAnswer = '';
  List<String> _options = [];
  bool _isAILoading = false;
  final bool _isFadingOut = false;
  bool _isSpeaking = false;
  late PatientIntent _intent;
  late AppLanguage _currentLanguage;
  
  // Blink Detection State
  final BlinkService _blinkService = BlinkService();
  CameraController? _cameraController;
  int _currentBlinkCount = 0;
  bool _useBlink = true;
  bool _isDemoMode = false;
  bool _pulse = false;
  Timer? _demoTimer;
  Timer? _readingTimer;
  int _countdown = 10;
  bool _canBlink = false;
  String _blinkStatus = "Initializing...";

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.language;
    _intent = PatientIntent.detect(widget.question);
    _initOptions();
    _initTts();
    _initCamera();
    _setupBlinkListeners();
  }

  void _setupBlinkListeners() {
    _blinkService.statusStream.listen((status) {
      if (mounted) setState(() => _blinkStatus = status);
    });

    _blinkService.countStream.listen((count) {
      if (mounted) setState(() => _currentBlinkCount = count);
    });

    _blinkService.blinkStream.listen((_) {
      if (mounted) {
        setState(() => _pulse = true);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _pulse = false);
        });
      }
    });

    _blinkService.selectionStream.listen((index) {
      if (mounted && _useBlink && _canBlink) {
        if (index < _options.length) {
          _speak(_options[index]);
        }
      }
    });
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    // Front camera is usually last or has lensDirection front
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first);
    
    _cameraController = CameraController(
      front, 
      ResolutionPreset.medium, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await _cameraController!.initialize();
    
    if (mounted) {
      int frameCount = 0;
      _cameraController!.startImageStream((image) {
        frameCount++;
        if (frameCount % 2 != 0 || !_useBlink || _isDemoMode) return; // Process every 2nd frame
        
        final inputImage = BlinkService.convertCameraImage(image, front);
        if (inputImage != null) {
          _blinkService.processImage(inputImage);
        }
      });
      setState(() {});
    }
  }

  void _toggleDemoMode(bool val) {
    setState(() {
      _isDemoMode = val;
      _demoTimer?.cancel();
      if (_isDemoMode) {
        _demoTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
          _blinkService.simulateBlink();
        });
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _cameraController?.dispose();
    _blinkService.dispose();
    _demoTimer?.cancel();
    _readingTimer?.cancel();
    super.dispose();
  }

  void _initOptions() async {
    if (_intent == PatientIntent.condition || _intent == PatientIntent.unknown) {
      setState(() => _isAILoading = true);
      final aiOptions = await AIService.generateOptions(widget.question, _currentLanguage, AppSettings().aiApiKey);
      if (mounted) {
        setState(() {
          _options = aiOptions.isNotEmpty ? aiOptions : _intent.optionKeys;
          _isAILoading = false;
          _startReadingTimer();
        });
      }
    } else {
      _options = _intent.optionKeys;
      _startReadingTimer();
    }
  }

  void _startReadingTimer() {
    setState(() {
      _canBlink = false;
      _countdown = 10;
    });
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            _canBlink = true;
            _readingTimer?.cancel();
          }
        });
      } else {
        _readingTimer?.cancel();
      }
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage(_currentLanguage.code);
    await _flutterTts.setSpeechRate(AppSettings().speechRate);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        
        // Auto reset flow: delay 1.0 seconds then pop to DoctorInputScreen
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  Future<void> _speak(String textOrKey) async {
    if (_isFadingOut || _isSpeaking) return;
    
    final tText = translations[textOrKey]?[_currentLanguage] ?? textOrKey;
    final enhancedText = enhancedSentences[textOrKey]?[_currentLanguage] ?? (tText.length < 5 ? "$tText, I am." : tText);
    
    setState(() {
      _selectedAnswer = tText;
      _isSpeaking = true;
    });
    
    await _flutterTts.stop();
    await _flutterTts.setLanguage(_currentLanguage.code);
    await _flutterTts.speak(enhancedText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF00D2FF).withValues(alpha: 0.3))),
              child: Row(children: [const Icon(Icons.psychology, size: 16, color: Color(0xFF00D2FF)), const SizedBox(width: 8), Text(_intent.label.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
            ),
          )
        ],
      ),
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: _isFadingOut ? 0.0 : 1.0,
        child: Column(
          children: [
            if (_useBlink)
              Container(
                height: MediaQuery.of(context).size.height * 0.40,
                width: double.infinity,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_cameraController != null && _cameraController!.value.isInitialized)
                      CameraPreview(_cameraController!),
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.2), BlendMode.darken),
                      child: Container(color: Colors.transparent),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: const BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.all(Radius.circular(20))),
                          child: const Text("Align your face here", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 220, height: 280,
                        decoration: BoxDecoration(
                          border: Border.all(color: _blinkStatus == "Face Detected" || _blinkStatus == "Blink Detected" ? const Color(0xFF00FFC2) : Colors.white38, width: 3),
                          borderRadius: BorderRadius.circular(150),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 320),
                        child: Text(_blinkStatus, style: TextStyle(color: _blinkStatus == "Face Detected" || _blinkStatus == "Blink Detected" ? const Color(0xFF00FFC2) : Colors.white, fontSize: 18, fontWeight: FontWeight.bold, backgroundColor: Colors.black54)),
                      ),
                    ),
                    if (_pulse)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF00FFC2), width: 8),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // 1. Question Card
                    GlassCard(
                      blur: 20, opacity: 0.15, color: const Color(0xFF00D2FF),
                      child: Column(
                        children: [
                          Text(widget.question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                          if (_isSpeaking) ...[
                            const SizedBox(height: 16),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.volume_up, color: Color(0xFF00FFC2), size: 16),
                                SizedBox(width: 8),
                                Text("Speaking...", style: TextStyle(color: Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 2. Selected Answer (if any)
                    if (_selectedAnswer.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text("Selected: $_selectedAnswer", style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    
                    // 3. Blink Status & Instructions
                    if (_useBlink && !_isAILoading && _selectedAnswer.isEmpty) 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            if (!_canBlink) ...[
                              Text("Please read the options... $_countdown", style: const TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                            ] else ...[
                              const Text("You can respond now", style: TextStyle(color: Color(0xFF00FFC2), fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                            ],
                            Text("Blink Count: $_currentBlinkCount", style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            const Text("1 blink: Option 1 | 2 blinks: Option 2 | 3 blinks: Option 3", style: TextStyle(fontSize: 12, color: Colors.white54)),
                          ],
                        ),
                      ),
                    
                    // 4. Mode Toggles
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OptionToggle(label: "Blink Detection", value: _useBlink, onChanged: (v) => setState(() => _useBlink = v)),
                        const SizedBox(width: 16),
                        _OptionToggle(label: "Demo Mode", value: _isDemoMode, onChanged: _toggleDemoMode),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 5. Response Options
                    if (_isAILoading)
                      const Column(children: [
                        CircularProgressIndicator(color: Color(0xFF00D2FF)),
                        const SizedBox(height: 16),
                        Text("Analyzing question...", style: TextStyle(color: Color(0xFF00D2FF), letterSpacing: 2, fontSize: 13, fontWeight: FontWeight.bold)),
                      ])
                    else ...[
                      const Text("AI Generated Responses", style: TextStyle(color: Color(0xFF8BA6B8), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      const SizedBox(height: 16),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _selectedAnswer.isNotEmpty ? 0.0 : 1.0,
                        child: IgnorePointer(
                          ignoring: _selectedAnswer.isNotEmpty,
                          child: Column(
                            children: _options.map((opt) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ResponseButton(
                                label: translations[opt]?[_currentLanguage] ?? opt,
                                color: _getOptionColor(opt),
                                onPressed: () => _speak(opt),
                                isSelected: _selectedAnswer == (translations[opt]?[_currentLanguage] ?? opt),
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                    
                    if (_selectedAnswer.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("Listening for next input...", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getOptionColor(String opt) {
    if (opt == 'Yes' || opt == 'Good') return const Color(0xFF00FFC2);
    if (opt == 'No' || opt == 'Bad' || opt == 'Urgent') return const Color(0xFFEF4444);
    if (opt == 'Severe' || opt == 'Okay') return const Color(0xFFF59E0B);
    return const Color(0xFF00D2FF);
  }
}

class _ResponseButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isSelected;

  const _ResponseButton({required this.label, required this.color, required this.onPressed, this.isSelected = false});

  @override
  State<_ResponseButton> createState() => _ResponseButtonState();
}

class _ResponseButtonState extends State<_ResponseButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _glow = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool activeGlow = _glow || widget.isSelected;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        setState(() => _glow = true);
        Future.delayed(const Duration(milliseconds: 500), () { if (mounted) setState(() => _glow = false); });
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF162D3D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.color.withValues(alpha: activeGlow ? 1.0 : 0.4), width: 2),
            boxShadow: [if (activeGlow) BoxShadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 4)],
          ),
          child: Center(child: Text(widget.label, style: TextStyle(color: widget.color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1), semanticsLabel: widget.label)),
        ),
      ),
    );
  }
}

class _OptionToggle extends StatelessWidget {
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _OptionToggle({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF00FFC2).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? const Color(0xFF00FFC2) : Colors.white24, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? Icons.check_circle : Icons.circle_outlined, size: 14, color: value ? const Color(0xFF00FFC2) : Colors.white54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: value ? const Color(0xFF00FFC2) : Colors.white54, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
