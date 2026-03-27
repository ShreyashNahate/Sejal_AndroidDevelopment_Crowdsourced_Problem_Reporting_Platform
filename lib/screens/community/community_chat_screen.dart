import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

/// Community chat screen — real-time city-based group chat using Firestore.
class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final _db = FirebaseFirestore.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Collection path: community_chat/{city}/messages
  CollectionReference _messagesRef(String city) {
    return _db.collection('community_chat').doc(city).collection('messages');
  }

  Future<void> _sendMessage(String city, String userId, String userName) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Basic spam check — no empty or single char messages
    if (text.length < 2) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await _messagesRef(city).add({
        'text': text,
        'user_id': userId,
        'user_name': userName,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      // Scroll to bottom after send
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Send message error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send. Try again.')),
      );
    }

    setState(() => _isSending = false);
  }

  Future<void> _upvoteMessage(
      String city, String docId, List upvotedBy, String userId) async {
    if (upvotedBy.contains(userId)) return; // already upvoted
    await _messagesRef(city).doc(docId).update({
      'upvotes': FieldValue.increment(1),
      'upvoted_by': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final city = auth.city.isEmpty ? 'General' : auth.city;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.people, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Community Chat', style: TextStyle(fontSize: 16)),
                Text(
                  '📍 $city',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Notice banner ──
          Container(
            width: double.infinity,
            color: AppColors.primary.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chat with citizens in $city. Discuss local issues, share updates.',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          // ── Messages list ──
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesRef(city)
                  .orderBy('created_at', descending: false)
                  .limitToLast(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _EmptyChat(city: city);
                }

                final docs = snapshot.data!.docs;

                // Auto scroll on new message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['user_id'] == auth.userId;
                    final upvotedBy =
                        List<String>.from(data['upvoted_by'] ?? []);
                    final upvotes = data['upvotes'] ?? 0;
                    final alreadyUpvoted = upvotedBy.contains(auth.userId);

                    return _ChatBubble(
                      docId: docs[i].id,
                      text: data['text'] ?? '',
                      userName: data['user_name'] ?? 'Citizen',
                      isMe: isMe,
                      upvotes: upvotes,
                      alreadyUpvoted: alreadyUpvoted,
                      createdAt: data['created_at'] as int? ?? 0,
                      onUpvote: isMe
                          ? null
                          : () => _upvoteMessage(
                                city,
                                docs[i].id,
                                upvotedBy,
                                auth.userId,
                              ),
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar ──
          _ChatInput(
            controller: _textController,
            isSending: _isSending,
            onSend: () => _sendMessage(city, auth.userId, auth.userName),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ──
class _EmptyChat extends StatelessWidget {
  final String city;
  const _EmptyChat({required this.city});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💬', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            'No messages in $city yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to start the conversation!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Chat bubble ──
class _ChatBubble extends StatelessWidget {
  final String docId;
  final String text;
  final String userName;
  final bool isMe;
  final int upvotes;
  final bool alreadyUpvoted;
  final int createdAt;
  final VoidCallback? onUpvote;

  const _ChatBubble({
    required this.docId,
    required this.text,
    required this.userName,
    required this.isMe,
    required this.upvotes,
    required this.alreadyUpvoted,
    required this.createdAt,
    required this.onUpvote,
  });

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withOpacity(0.2),
              child: Text(
                userName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Name + time
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3, left: 4),
                    child: Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                // Bubble
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),

                // Time + upvote row
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(createdAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    if (!isMe && onUpvote != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: alreadyUpvoted ? null : onUpvote,
                        child: Row(
                          children: [
                            Icon(
                              alreadyUpvoted
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                              size: 13,
                              color: alreadyUpvoted
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$upvotes',
                              style: TextStyle(
                                fontSize: 11,
                                color: alreadyUpvoted
                                    ? AppColors.primary
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ──
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Share with your community...',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isSending ? Colors.grey : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
