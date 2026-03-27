import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'blink_service.dart';
import 'ai_service.dart';
import 'memory_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings().init();
  runApp(const EchoMindAiApp());
}




class DemoStep {
  final String question;
  final List<String> options;
  final String autoSelect;

  const DemoStep({required this.question, required this.options, required this.autoSelect});
}

final List<DemoStep> demoSteps = [
  const DemoStep(question: "Do you feel pain?", options: ["Yes", "No"], autoSelect: "Yes"),
  const DemoStep(question: "Is it severe?", options: ["Mild", "Severe"], autoSelect: "Mild"),
  const DemoStep(question: "Where is the pain?", options: ["Head", "Chest", "Back"], autoSelect: "Chest"),
  const DemoStep(question: "Are you breathing properly?", options: ["Yes", "No", "Difficulty"], autoSelect: "Difficulty"),
];

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
  bool isFirstRun = true;
  bool isDemoMode = false;

  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    aiApiKey = _prefs.getString('aiApiKey') ?? '';
    speechRate = _prefs.getDouble('speechRate') ?? 0.45;
    isFirstRun = _prefs.getBool('isFirstRun') ?? true;
    isDemoMode = _prefs.getBool('isDemoMode') ?? false;
  }

  Future<void> save() async {
    await _prefs.setString('aiApiKey', aiApiKey);
    await _prefs.setDouble('speechRate', speechRate);
    await _prefs.setBool('isFirstRun', isFirstRun);
    await _prefs.setBool('isDemoMode', isDemoMode);
  }
}

class EchoMindAiApp extends StatefulWidget {
  const EchoMindAiApp({super.key});

  @override
  State<EchoMindAiApp> createState() => _EchoMindAiAppState();
}

class _EchoMindAiAppState extends State<EchoMindAiApp> {
  final List<String> _history = [];
  bool _showSetup = false;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    // Setup is required if there's no API key AND it's the first run
    _showSetup = AppSettings().isFirstRun && AppSettings().aiApiKey.isEmpty;
    // Onboarding shows if it's first run AND API key is already set (or after setup)
    _showOnboarding = AppSettings().isFirstRun && AppSettings().aiApiKey.isNotEmpty;
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
      home: _showSetup
        ? SetupScreen(onComplete: (apiKey) {
            AppSettings().aiApiKey = apiKey;
            // Note: We don't set isFirstRun = false yet, we want onboarding next
            AppSettings().save();
            setState(() {
              _showSetup = false;
              _showOnboarding = true;
            });
          })
        : _showOnboarding 
          ? OnboardingScreen(onComplete: () {
              AppSettings().isFirstRun = false;
              AppSettings().save();
              setState(() => _showOnboarding = false);
            })
          : DoctorInputScreen(
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
  final EdgeInsets? padding;

  const GlassCard({
    super.key, 
    required this.child, 
    this.blur = 10, 
    this.opacity = 0.1, 
    this.color = Colors.white,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
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
  final List<String> history;
  final Function(String) onQuestionSubmitted;

  const DoctorInputScreen({
    super.key, 
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
  bool _isDemoMode = AppSettings().isDemoMode;
  bool _isDemoRunning = false;
  int _currentDemoStep = 0;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (_isDemoMode) {
        _runDemoIteration();
      }
    });
  }

  void _toggleDemoMode(bool val) {
    if (mounted) {
      setState(() {
        _isDemoMode = val;
        AppSettings().isDemoMode = val;
        AppSettings().save();
        if (_isDemoMode) {
          if (!_isDemoRunning) {
            _isDemoRunning = true;
            _currentDemoStep = 0;
            _stopListening();
            _runDemoIteration();
          }
        } else {
          _isDemoRunning = false;
          _isProcessing = false;
          _questionController.clear();
          _startListening();
        }
      });
    }
  }

  void _runDemoIteration() async {
    if (!_isDemoMode || !_isDemoRunning || !mounted) return;
    
    if (_currentDemoStep >= demoSteps.length) {
      setState(() {
        _isDemoMode = false;
        _isDemoRunning = false;
        _isProcessing = false;
        _questionController.clear();
        AppSettings().isDemoMode = false;
        AppSettings().save();
      });
      _startListening();
      return;
    }
    
    final step = demoSteps[_currentDemoStep];
    
    setState(() {
      _questionController.text = step.question;
      _isProcessing = true;
    });
    
    // Step 1: Show question -> wait 2-3 sec
    await Future.delayed(const Duration(seconds: 3));
    
    if (!_isDemoMode || !_isDemoRunning || !mounted) return;
    
    // Step 2-4: Show options -> wait 3-4 sec -> Highlight -> Speak
    await _navigateToResponse(step.question, isDemo: true, demoOptions: step.options, demoAutoSelect: step.autoSelect);
    
    if (!_isDemoMode || !_isDemoRunning || !mounted) return;
    
    _currentDemoStep++;
    _runDemoIteration();
  }

  void _initSpeech() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) {
        if (!_isDemoMode && (status == 'done' || status == 'notListening')) {
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
    if (available && mounted && !_isDemoMode) {
      _startListening();
    }
  }

  void _handleAutoSubmit() async {
    if (_isDemoMode) return;
    _idleTimer?.cancel();
    setState(() { _isProcessing = true; _isListening = false; });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      final q = _questionController.text;
      widget.onQuestionSubmitted(q);
      _questionController.clear();
      await _navigateToResponse(q);
      
      if (mounted) {
        setState(() { _isProcessing = false; });
        _focusNode.requestFocus();
        _startListening();
      }
    }
  }

  Future<void> _navigateToResponse(String question, {bool isDemo = false, List<String> demoOptions = const [], String demoAutoSelect = ''}) async {
    await Navigator.push(
      context, 
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ResponseSelectionScreen(
          question: question, 
          isDemo: isDemo,
          demoOptions: demoOptions,
          demoAutoSelect: demoAutoSelect,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      )
    );
  }

  void _startListening() async {
    if (_isDemoMode) return;
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
          title: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("EchoMind AI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00D2FF), overflow: TextOverflow.ellipsis)),
                const Text("Assistive Communication System", style: TextStyle(fontSize: 10, color: Colors.white38, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: Color(0xFF00D2FF), size: 18),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                    ),
                    _OptionToggle(
                      label: "Demo", 
                      value: _isDemoMode, 
                      onChanged: _toggleDemoMode
                    ),
                  ],
                ),
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
                            hintText: "Type a question or use mic...",
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
              color: Color(0xFF00FFC2).withValues(alpha: 0.1),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF00FFC2)),
                    const SizedBox(height: 20),
                    const Text("Processing Medical Intent...", style: TextStyle(color: Color(0xFF00FFC2), fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (AppSettings().isDemoMode) 
                      const Text("Demo Running...", style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
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
      body: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 80),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D2FF),
                    foregroundColor: const Color(0xFF162D3D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ), 
                  child: const Text("Save Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ResponseSelectionScreen extends StatefulWidget {
  final String question;
  final bool isDemo;
  final List<String> demoOptions;
  final String demoAutoSelect;

  const ResponseSelectionScreen({
    super.key, 
    required this.question, 
    this.isDemo = false,
    this.demoOptions = const [],
    this.demoAutoSelect = '',
  });

  @override
  State<ResponseSelectionScreen> createState() => _ResponseSelectionScreenState();
}

class _ResponseSelectionScreenState extends State<ResponseSelectionScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _blinkPlayer = AudioPlayer();
  final AudioPlayer _tapPlayer = AudioPlayer();
  final AudioPlayer _tonePlayer = AudioPlayer();

  late String _displayQuestion;
  String _selectedAnswer = '';
  List<String> _options = [];
  bool _isAILoading = false;
  final bool _isFadingOut = false;
  bool _isSpeaking = false;
  bool _isEnhancing = false;
  late PatientIntent _intent;
  final List<String> _responseBuffer = [];

  // Derives the current status label/emoji/color from app state
  ({String label, String emoji, Color color}) get _systemStatus {
    if (_isSpeaking)        return (label: 'Speaking...',           emoji: '🔊', color: const Color(0xFF00FFC2));
    if (_isEnhancing)       return (label: 'Enhancing Response...', emoji: '✨', color: const Color(0xFF00FFC2));
    if (_isAILoading && _responseBuffer.isEmpty) return (label: 'Analyzing Question...', emoji: '🧠', color: const Color(0xFF00D2FF));
    if (_isAILoading && _responseBuffer.isNotEmpty) return (label: 'Generating Next Steps...', emoji: '⚡', color: const Color(0xFF00D2FF));
    if (_options.isNotEmpty && _selectedAnswer.isEmpty) return (label: 'Waiting for Input', emoji: '⏳', color: const Color(0xFFF59E0B));
    if (_useBlink && _options.isEmpty && !_isAILoading) return (label: 'Listening for Input', emoji: '🎤', color: const Color(0xFF00D2FF));
    return (label: 'Ready', emoji: '✅', color: const Color(0xFF00FFC2));
  }
  
  // Blink Detection State
  final BlinkService _blinkService = BlinkService();
  CameraController? _cameraController;
  int _currentBlinkCount = 0;
  bool _useBlink = true;
  bool _isDemoMode = false;
  bool _pulse = false;
  Timer? _demoTimer;
  String _blinkStatus = "Initializing...";

  @override
  void initState() {
    super.initState();
    _displayQuestion = widget.question;
    _intent = PatientIntent.detect(_displayQuestion);
    _initOptions();
    _initTts();
    _initCamera();
    _setupBlinkListeners();
    
    _blinkPlayer.setPlayerMode(PlayerMode.lowLatency);
    _tapPlayer.setPlayerMode(PlayerMode.lowLatency);
    _tonePlayer.setPlayerMode(PlayerMode.lowLatency);
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
        _blinkPlayer.play(AssetSource('sounds/blink_click.wav'));
        HapticFeedback.lightImpact();
        setState(() => _pulse = true);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _pulse = false);
        });
      }
    });

    _blinkService.selectionStream.listen((index) {
      if (mounted && _useBlink && !widget.isDemo) {
        if (index < _options.length) {
          _addToResponseBuffer(_options[index]);
        }
      }
    });

    _blinkService.longBlinkStream.listen((_) {
      if (mounted && _useBlink && !widget.isDemo && _responseBuffer.isNotEmpty) {
        _triggerFinalSpeech();
      }
    });
  }

  Future<void> _initCamera() async {
    if (widget.isDemo) {
      if (mounted) setState(() => _blinkStatus = "Demo Mode Active");
      return;
    }
    try {
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
          if (widget.isDemo) return;
          frameCount++;
          if (frameCount % 2 != 0 || !_useBlink) return; // Process every 2nd frame
          
          final inputImage = BlinkService.convertCameraImage(image, front);
          if (inputImage != null) {
            _blinkService.processImage(inputImage);
          }
        });
        setState(() {});
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _blinkStatus = 'Camera unavailable — using manual mode';
          _useBlink = false;
        });
      }
    }
  }

  void _toggleDemoMode(bool val) {
    if (widget.isDemo) return; // Ignore local toggle if driving from DoctorInputScreen
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
    _blinkPlayer.dispose();
    _tapPlayer.dispose();
    _tonePlayer.dispose();
    _flutterTts.stop();
    _cameraController?.dispose();
    _blinkService.dispose();
    _demoTimer?.cancel();
    super.dispose();
  }

  void _initOptions() async {
    if (widget.isDemo && widget.demoOptions.isNotEmpty) {
      if (mounted) {
        setState(() {
          _options = widget.demoOptions;
          _isAILoading = false;
        });
        _runDemoSequence();
      }
      return;
    }
    
    // Always use AI to generate options in the correct language for the question
    if (widget.isDemo) {
      setState(() => _options = _intent.optionKeys);
      return;
    }
    
    setState(() => _isAILoading = true);
    try {
      final aiOptions = await AIService.generateOptions(
        widget.question, 
        AppSettings().aiApiKey,
        contextQ: ConversationMemory.lastQuestion,
        contextA: ConversationMemory.lastAnswer,
      );
      if (mounted) {
        setState(() {
          _options = aiOptions.isNotEmpty ? aiOptions : _intent.optionKeys;
          _isAILoading = false;
        });
      }
    } catch (e) {
      debugPrint('AI options error: $e');
      if (mounted) {
        setState(() {
          _options = ['Yes', 'No', 'Help'];
          _isAILoading = false;
        });
      }
    }
  }

  void _runDemoSequence() async {
    if (!widget.isDemo || widget.demoAutoSelect.isEmpty) return;
    
    // Step 2: Show options -> wait 3-4 sec
    await Future.delayed(const Duration(seconds: 4));
    
    if (!mounted || !widget.isDemo) return;
    
    // Step 3: Highlight selected option -> 1 sec
    setState(() {
      _selectedAnswer = widget.demoAutoSelect;
    });
    
    await Future.delayed(const Duration(seconds: 1));
    
    if (!mounted || !widget.isDemo) return;
    
    // Step 4: Speak answer
    _speak(widget.demoAutoSelect);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-IN');
    await _flutterTts.setSpeechRate(AppSettings().speechRate);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  String _detectLanguage(String text) {
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0x0900 && code <= 0x097F) return "hi-IN";
      if (code >= 0x0980 && code <= 0x09FF) return "bn-IN";
    }
    return "en-US";
  }

  String _buildFinalSentence() {
    if (_responseBuffer.isEmpty) return "";
    String prefix = "";
    List<String> remaining = List.from(_responseBuffer);
    final first = remaining.first.toLowerCase();
    if (first == "yes" || first == "no" || first == "ha" || first == "na" || first == "haan") {
      prefix = "${remaining.removeAt(0)}, ";
    }
    if (remaining.isEmpty) return prefix.replaceAll(", ", "");
    final mainPart = remaining.join(" ").toLowerCase();
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

  String _formatSpeech(String text) {
    if (text.isEmpty) return "";
    String formatted = text.trim();
    if (!formatted.endsWith('.') && !formatted.endsWith('?') && !formatted.endsWith('!')) {
      formatted += '.';
    }
    if (formatted.isNotEmpty) {
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    }
    return formatted;
  }

  Future<void> _speak(String text) async {
    if (_isFadingOut || _isSpeaking) return;
    
    // Clean and trim the text for accurate TTS
    final cleanText = text.trim();
    final lang = _detectLanguage(cleanText);
    
    // Format the speech output for natural sentences
    final speechOutput = _formatSpeech(cleanText);
    
    // Low-pitch soft pop & custom tone to indicate speaking starts
    HapticFeedback.mediumImpact();
    _tonePlayer.play(AssetSource('sounds/speak_tone.wav'));
    
    // Validation: Log exact text sent to TTS
    debugPrint('TTS SPEAKING: "$speechOutput" (Original: "$cleanText", Language: $lang)');
    
    setState(() {
      _selectedAnswer = cleanText;
      _isSpeaking = true;
    });
    
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(lang);
      await _flutterTts.speak(speechOutput);
    } catch (e) {
      debugPrint('TTS error: $e');
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _selectedAnswer = '';
          _blinkStatus = 'Something went wrong, continuing...';
        });
      }
    }
  }

  Future<void> _addToResponseBuffer(String opt) async {
    if (_isAILoading || _isSpeaking) return;
    
    _tapPlayer.play(AssetSource('sounds/option_tap.wav'));
    HapticFeedback.selectionClick();
    
    setState(() {
      _selectedAnswer = opt; // Highlight selection
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    setState(() {
      _responseBuffer.add(opt);
      _options = [];
      _isAILoading = true;
      _selectedAnswer = '';
    });

    // We no longer auto-trigger speech by default, 
    // but we can suggest finalization if the buffer is long.
    if (_responseBuffer.length >= 5) {
      _triggerFinalSpeech();
      return;
    }

    try {
      final nextOptions = await AIService.generateOptions(
        _displayQuestion, 
        AppSettings().aiApiKey,
        currentBuffer: _responseBuffer,
      );
      
      if (mounted) {
        setState(() {
          _options = nextOptions.isNotEmpty ? nextOptions : ["End & Speak", "Wait", "More"];
          _isAILoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _options = ["End & Speak", "Back", "More"];
          _isAILoading = false;
        });
      }
    }
  }


  Future<void> _triggerFinalSpeech() async {
    final originalSentence = _buildFinalSentence();
    if (originalSentence.isEmpty) return;

    String sentenceToSpeak = originalSentence;

    // AI Enhancement Layer
    setState(() => _isEnhancing = true);
    try {
      final enhanced = await AIService.enhanceSentence(originalSentence, AppSettings().aiApiKey);
      if (enhanced != null && enhanced.isNotEmpty) {
        sentenceToSpeak = enhanced;
        debugPrint('AI ENHANCED: "$sentenceToSpeak" (Original: "$originalSentence")');
      }
    } catch (e) {
      debugPrint('AI enhancement error: $e');
    } finally {
      if (mounted) setState(() => _isEnhancing = false);
    }

    // Save interaction to memory before speaking
    ConversationMemory.saveInteraction(_displayQuestion, sentenceToSpeak);
    
    _speak(sentenceToSpeak);
    
    if (mounted) {
      setState(() {
        _responseBuffer.clear();
      });
    }
  }

  void _resetSession() {
    _tapPlayer.play(AssetSource('sounds/option_tap.wav'));
    HapticFeedback.mediumImpact();
    setState(() {
      _displayQuestion = "Ready for next input";
      _options = ["Yes", "No", "Help"]; // Safe fallback options
      _responseBuffer.clear();
      _selectedAnswer = '';
      _isAILoading = false;
      _isSpeaking = false;
      _intent = PatientIntent.detect(_displayQuestion);
    });
    ConversationMemory.clear();
    _blinkService.resetCount();
    _flutterTts.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orangeAccent),
            tooltip: 'Reset Session',
            onPressed: _resetSession,
          ),
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
        child: SafeArea(
          child: Column(
            children: [
              if (_useBlink)
                Container(
                  height: MediaQuery.of(context).size.height * 0.35,
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
                      child: _FaceGuide(status: _blinkStatus),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text("Focus on camera", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                      ),
                    ),
                     if (_pulse)
                       AnimatedContainer(
                         duration: const Duration(milliseconds: 200),
                         decoration: BoxDecoration(
                           boxShadow: [
                             BoxShadow(color: const Color(0xFF00FFC2).withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10),
                           ],
                         ),
                       ),
                  ],
                ),
              ),
            // 0. System Status Bar
            _SystemStatusBar(
              label: _systemStatus.label,
              emoji: _systemStatus.emoji,
              color: _systemStatus.color,
              blinkDetail: widget.isDemo ? 'DEMO RUNNING...' : _blinkStatus,
              isDemo: widget.isDemo,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // 1. Question Card
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.25),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        blur: 20, opacity: 0.15, color: const Color(0xFF00D2FF),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _displayQuestion, 
                              textAlign: TextAlign.center, 
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)
                            ),
                            if (_isSpeaking) ...[
                              const SizedBox(height: 8),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.volume_up, color: Color(0xFF00FFC2), size: 14),
                                  SizedBox(width: 8),
                                  Text("Speaking...", style: TextStyle(color: Color(0xFF00FFC2), fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 2. Selected Answer (if any)
                    if (_responseBuffer.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          color: const Color(0xFF00FFC2),
                          opacity: 0.08,
                          blur: 15,
                          child: Column(
                            children: [
                              const Text("BUILDING RESPONSE", style: TextStyle(color: Color(0xFF00D2FF), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.5)),
                              const SizedBox(height: 16),
                              Text(
                                _responseBuffer.join(" → "), 
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFF00FFC2), fontWeight: FontWeight.bold, fontSize: 30, letterSpacing: -0.5)
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: 200,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _triggerFinalSpeech,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00D2FF),
                                    foregroundColor: const Color(0xFF0B1E2D),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                    elevation: 8,
                                    shadowColor: const Color(0xFF00D2FF).withValues(alpha: 0.5),
                                  ),
                                  child: const Text("SPEAK NOW", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // 3. Blink Status & Instructions
                    const SizedBox(height: 16),


                    // 5. Response Options
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child)),
                        child: _isAILoading
                            ? Column(
                                key: const ValueKey('loading'),
                                children: [
                                  const SizedBox(height: 20),
                                  const CircularProgressIndicator(color: Color(0xFF00D2FF)),
                                  const SizedBox(height: 12),
                                  const Text("Generating next steps...", style: TextStyle(color: Color(0xFF00D2FF), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 20),
                                ],
                              )
                            : Column(
                                key: ValueKey('options_${_options.join('')}'),
                                children: [
                                  const Text("Available Options", style: TextStyle(color: Color(0xFF8BA6B8), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.3)),
                                  const SizedBox(height: 12),
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 400),
                                    opacity: _selectedAnswer.isNotEmpty ? 1.0 : 1.0, // Always visible now
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _options.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final opt = _options[index];
                                        return _ResponseButton(
                                          label: opt,
                                          color: _getOptionColor(opt),
                                          onPressed: () => _addToResponseBuffer(opt),
                                          isSelected: _selectedAnswer == opt,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    
                    const SizedBox(height: 48),

                    // 6. Blink Status & Instructions (Now in Footer area)
                    if (_useBlink && !_isAILoading && _selectedAnswer.isEmpty) 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          color: const Color(0xFF00FFC2),
                          opacity: 0.05,
                          child: Column(
                            children: [
                              const Text("Detection Active", style: TextStyle(color: Color(0xFF00FFC2), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Text("$_currentBlinkCount Blinks", style: const TextStyle(color: Color(0xFF00FFC2), fontSize: 32, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white10, height: 1),
                              const SizedBox(height: 12),
                              const Text(
                                "Select options: 1-3 blinks\nConfirm & Speak: Long-blink or press Speak",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: Colors.white70, letterSpacing: 0.5, fontWeight: FontWeight.bold, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 32),

                    // 7. System Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OptionToggle(label: "Blink Control", value: _useBlink, onChanged: (v) => setState(() => _useBlink = v)),
                        const SizedBox(width: 16),
                        _OptionToggle(label: "Simulator", value: _isDemoMode, onChanged: _toggleDemoMode),
                      ],
                    ),
                    const SizedBox(height: 40),
                    
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
            color: activeGlow ? widget.color.withValues(alpha: 0.15) : const Color(0xFF162D3D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withValues(alpha: activeGlow ? 1.0 : 0.3), width: 2),
            boxShadow: [
              if (activeGlow) 
                BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(
              widget.label, 
              style: TextStyle(color: widget.color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5), 
              semanticsLabel: widget.label
            )
          ),
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



class _SystemStatusBar extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final String blinkDetail;
  final bool isDemo;

  const _SystemStatusBar({
    required this.label,
    required this.emoji,
    required this.color,
    required this.blinkDetail,
    required this.isDemo,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                child: Text(label),
              ),
            ],
          ),
          if (blinkDetail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              blinkDetail,
              style: TextStyle(
                color: isDemo ? Colors.orangeAccent : Colors.white54,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: isDemo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaceGuide extends StatefulWidget {
  final String status;
  const _FaceGuide({required this.status});

  @override
  State<_FaceGuide> createState() => _FaceGuideState();
}

class _FaceGuideState extends State<_FaceGuide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String displayStatus = "Align Face";
    Color borderColor = Colors.white38;
    bool isLocked = false;

    if (widget.status.contains("Stable")) {
      displayStatus = "Face Locked ✅";
      borderColor = const Color(0xFF00FFC2);
      isLocked = true;
    } else if (widget.status.contains("Blink") || widget.status.contains("Detected")) {
      displayStatus = "Detecting...";
      borderColor = Colors.orangeAccent;
    }

    return ScaleTransition(
      scale: _animation,
      child: Container(
        width: 220, height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(150),
          border: Border.all(color: borderColor, width: 4),
          boxShadow: [
            if (isLocked) BoxShadow(color: borderColor.withValues(alpha: 0.5), blurRadius: 25, spreadRadius: 5),
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLocked) const Icon(Icons.check_circle_outline, color: Color(0xFF00FFC2), size: 48),
              const SizedBox(height: 12),
              Text(
                displayStatus, 
                textAlign: TextAlign.center,
                style: TextStyle(color: borderColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


