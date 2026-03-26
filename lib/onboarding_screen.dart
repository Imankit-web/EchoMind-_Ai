import 'package:flutter/material.dart';
import 'main.dart'; 

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = AppSettings().userName;
    _apiKeyController.text = AppSettings().aiApiKey;
  }

  void _saveAndContinue() async {
    final settings = AppSettings();
    settings.userName = _nameController.text.trim();
    settings.aiApiKey = _apiKeyController.text.trim();
    settings.isFirstRun = false;
    await settings.save();
    
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.health_and_safety, size: 80, color: Color(0xFF00D2FF)),
                const SizedBox(height: 24),
                const Text(
                  "Welcome to EchoMind AI",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Doctor Assist Mode Setup",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF8BA6B8)),
                ),
                const SizedBox(height: 48),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Doctor Name (Optional)", style: TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: "Dr. Smith",
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Groq API Key (Recommended)", style: TextStyle(color: Color(0xFF00D2FF), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "Enter your Groq API Key",
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFC2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: const Color(0xFF00FFC2).withValues(alpha: 0.5),
                  ),
                  child: const Text("Save & Continue", style: TextStyle(color: Color(0xFF162D3D), fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
