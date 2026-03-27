import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';

// ─────────────────────────────────────────────
// 🔧 REPLACE with your Gemini API key
const _groqApiKey =
    'YOUR_API_KEY'; // ─────────────────────────────────────────────

/// Data model for a single chat message
class ChatMessage {
  final String text;
  final bool isUser;
  final String? suggestedCategory;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.suggestedCategory,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

/// Chatbot screen with rule-based Q&A, Gemini AI fallback, and TTS.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  bool _isListening = false;
  bool _isThinking = false; // Gemini loading indicator
  int? _currentlyReadingIndex; // which bubble is being read aloud

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    // In initState, add this line:
    // _listAvailableModels();

    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _currentlyReadingIndex = null);
    });

    _addBotMessage(
      '👋 Hello! I\'m SmartCity Assistant.\n\nI can help you:\n'
      '• Report civic issues\n'
      '• Find the right category\n'
      '• Answer questions about the app\n\n'
      'What problem are you facing today?',
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _addUserMessage(String text) {
    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _scrollToBottom();
  }

  void _addBotMessage(String text, {String? suggestedCategory}) {
    setState(() => _messages.add(ChatMessage(
          text: text,
          isUser: false,
          suggestedCategory: suggestedCategory,
        )));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── TTS ────────────────────────────────────
  Future<void> _speak(String text, int index) async {
    if (_currentlyReadingIndex == index) {
      // Already reading this bubble → stop
      await _tts.stop();
      setState(() => _currentlyReadingIndex = null);
      return;
    }
    await _tts.stop();
    setState(() => _currentlyReadingIndex = index);
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  }

// Add this method to _ChatbotScreenState
  // Future<void> _listAvailableModels() async {
  //   final response = await http.get(Uri.parse(
  //       'https://generativelanguage.googleapis.com/v1beta/models?key=$_geminiApiKey'));
  //   debugPrint('Available models: ${response.body}');
  // }

  // ── Gemini API call ─────────────────────────
  // Replace entire _askGemini method with:
  // Replace entire _askHuggingFace method with:
  Future<String> _askGroq(String userMessage) async {
    const url = 'https://api.groq.com/openai/v1/chat/completions';

    final body = jsonEncode({
      'model': 'llama-3.3-70b-versatile',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are SmartCity Assistant for Indian cities. Help users report civic issues like potholes, garbage, water leaks, electricity problems. Keep answers short, friendly, max 2-3 sentences.'
        },
        {'role': 'user', 'content': userMessage}
      ],
      'max_tokens': 150,
      'temperature': 0.7,
    });

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_groqApiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices']?[0]?['message']?['content'] as String?;
        return text?.trim() ?? 'Could not understand. Please try again.';
      } else {
        debugPrint('Groq error ${response.statusCode}: ${response.body}');
        return 'AI service unavailable. Please try again.';
      }
    } catch (e) {
      debugPrint('Groq exception: $e');
      return 'Connection error. Check your internet.';
    }
  }

  // ── Message processing ──────────────────────
  Future<void> _processMessage(String input) async {
    if (input.trim().isEmpty) return;

    final text = input.trim();
    _addUserMessage(text);
    _textController.clear();

    // 1. Try rule-based match first
    final lower = text.toLowerCase();
    Map<String, String>? matched;
    for (final qa in AppConstants.chatbotQA) {
      final triggers = qa['trigger']!.split('|');
      if (triggers.any((t) => lower.contains(t))) {
        matched = qa;
        break;
      }
    }

    if (matched != null) {
      await Future.delayed(const Duration(milliseconds: 600));
      _addBotMessage(matched['response']!,
          suggestedCategory: matched['category']);
      return;
    }

    // 2. Fallback → Gemini
    setState(() => _isThinking = true);
    _scrollToBottom();

    final geminiReply = await _askGroq(text);

    setState(() => _isThinking = false);
    _addBotMessage(geminiReply);
  }

  // ── Voice ───────────────────────────────────
  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          _textController.text = result.recognizedWords;
          if (result.finalResult) {
            _processMessage(result.recognizedWords);
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text('🤖', style: TextStyle(fontSize: 16)),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SmartCity Assistant', style: TextStyle(fontSize: 16)),
                Text('Online',
                    style: TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _QuickSuggestions(onSelect: _processMessage),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (ctx, i) {
                // Typing indicator at end
                if (_isThinking && i == _messages.length) {
                  return const _TypingIndicator();
                }
                return _ChatBubble(
                  message: _messages[i],
                  index: i,
                  isReading: _currentlyReadingIndex == i,
                  onCategoryUse: (_) => Navigator.pushNamed(context, '/report'),
                  onReadToggle: () => _speak(_messages[i].text, i),
                );
              },
            ),
          ),
          _ChatInput(
            controller: _textController,
            isListening: _isListening,
            onSend: _processMessage,
            onVoice: _toggleVoice,
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────
// WIDGETS
// ────────────────────────────────────────────────────────

class _QuickSuggestions extends StatelessWidget {
  final Function(String) onSelect;
  const _QuickSuggestions({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      'How to report?',
      'Garbage issue',
      'Water leak',
      'Road pothole',
      'Emergency!',
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions
              .map((s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      onPressed: () => onSelect(s),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      side: const BorderSide(
                          color: AppColors.primary, width: 0.5),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/// Animated "..." typing indicator shown while Gemini is thinking
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 60),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Text('🤖', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final step = (_ctrl.value * 3).floor();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == step
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.3),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual chat bubble with read-aloud toggle
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final int index;
  final bool isReading;
  final Function(String) onCategoryUse;
  final VoidCallback onReadToggle;

  const _ChatBubble({
    required this.message,
    required this.index,
    required this.isReading,
    required this.onCategoryUse,
    required this.onReadToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text('🤖', style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),

                // ── Read aloud button (bot messages only) ──
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onReadToggle,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isReading ? Icons.stop_circle : Icons.volume_up,
                          size: 15,
                          color: isReading
                              ? Colors.red
                              : AppColors.primary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isReading ? 'Stop reading' : 'Read aloud',
                          style: TextStyle(
                            fontSize: 11,
                            color: isReading
                                ? Colors.red
                                : AppColors.primary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Category suggestion button
                if (message.suggestedCategory != null) ...[
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    onPressed: () => onCategoryUse(message.suggestedCategory!),
                    icon: const Icon(Icons.add_a_photo, size: 16),
                    label: const Text('Use This Category to Report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Chat text input bar with voice button
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final Function(String) onSend;
  final VoidCallback onVoice;

  const _ChatInput({
    required this.controller,
    required this.isListening,
    required this.onSend,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onVoice,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isListening ? AppColors.emergency : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                color: isListening ? Colors.white : AppColors.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: isListening ? 'Listening...' : 'Ask me anything...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: onSend,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onSend(controller.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
