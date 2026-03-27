import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';

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

/// Chatbot screen with rule-based Q&A and voice input.
/// Helps users understand how to report issues and auto-suggests categories.
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
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    // Initial greeting from bot
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
    super.dispose();
  }

  /// Add a message from the user
  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();
  }

  /// Add a response from the bot
  void _addBotMessage(String text, {String? suggestedCategory}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        suggestedCategory: suggestedCategory,
      ));
    });
    _scrollToBottom();
  }

  /// Scroll chat to bottom after new messages
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

  /// Process user input and generate bot response using keyword matching
  void _processMessage(String input) {
    if (input.trim().isEmpty) return;

    final text = input.trim();
    _addUserMessage(text);
    _textController.clear();

    // Find matching Q&A from predefined list
    final lower = text.toLowerCase();
    Map<String, String>? matched;

    for (final qa in AppConstants.chatbotQA) {
      final triggers = qa['trigger']!.split('|');
      if (triggers.any((t) => lower.contains(t))) {
        matched = qa;
        break;
      }
    }

    // Simulate typing delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (matched != null) {
        _addBotMessage(
          matched['response']!,
          suggestedCategory: matched['category'],
        );
      } else {
        // Generic fallback response
        _addBotMessage(
          'I understand you have a civic issue. Could you describe it more? '
          'For example: "garbage not collected", "water pipe leak", "road pothole", etc.\n\n'
          'Or you can tap the "+" button on home to directly report an issue.',
        );
      }
    });
  }

  /// Toggle voice input
  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize(
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
          // Quick suggestion chips
          _QuickSuggestions(onSelect: _processMessage),

          // Chat messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _ChatBubble(
                message: _messages[i],
                onCategoryUse: (cat) {
                  Navigator.pushNamed(context, '/report');
                },
              ),
            ),
          ),

          // Input area
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

/// Quick suggestion buttons at top of chatbot
class _QuickSuggestions extends StatelessWidget {
  final Function(String) onSelect;
  const _QuickSuggestions({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final suggestions = [
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

/// Individual chat bubble
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onCategoryUse;

  const _ChatBubble({required this.message, required this.onCategoryUse});

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
                        horizontal: 12,
                        vertical: 6,
                      ),
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
          // Voice input button
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
          // Text input
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: onSend,
            ),
          ),
          const SizedBox(width: 8),
          // Send button
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
