import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SetupScreen extends StatefulWidget {
  final Function(String apiKey) onComplete;

  const SetupScreen({super.key, required this.onComplete});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isValid = _controller.text.trim().length > 10; // Basic check for common API key lengths
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1E2D),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, -0.6),
                radius: 1.2,
                colors: [
                  const Color(0xFF00D2FF).withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 40, right: 40,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/logo.png', width: 80, height: 80),
                  const SizedBox(height: 32),
                const Text(
                  "Welcome to EchoMind AI",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Setup required to enable intelligent clinical responses and vision tracking.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF8BA6B8), height: 1.4),
                ),
                const SizedBox(height: 60),
                
                // API Key Input Card
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("GROQ API KEY", style: TextStyle(color: Color(0xFF00D2FF), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _controller,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: "Paste your key here...",
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.2),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            suffixIcon: const Icon(Icons.vpn_key_rounded, color: Colors.white24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _isValid ? () => widget.onComplete(_controller.text.trim()) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFC2),
                      foregroundColor: const Color(0xFF0B1E2D),
                      disabledBackgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      elevation: _isValid ? 8 : 0,
                    ),
                    child: const Text("CONTINUE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
                
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => _launchURL("https://console.groq.com/keys"),
                  child: const Text("Get an API key from Groq Console", style: TextStyle(color: Color(0xFF00D2FF), decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  void _launchURL(String url) {
    // Basic clipboard feedback as fallback or just log
    debugPrint("Launch URL: $url");
    HapticFeedback.lightImpact();
  }
}
