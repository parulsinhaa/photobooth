// lib/features/chat/screens/chat_conversation_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/chat_message.dart';

class ChatConversationScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const ChatConversationScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver {
  final _messages = <ChatMessage>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isTyping = false;
  bool _partnerTyping = false;
  Timer? _typingTimer;
  Timer? _disappearTimer;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final token = LocalStorage.getString(AppConstants.tokenKey) ?? '';
    final wsUrl = '${AppConstants.wsUrl}/chat/${widget.userId}?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      setState(() => _isConnected = true);

      _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          setState(() => _isConnected = false);
          _reconnect();
        },
        onDone: () {
          setState(() => _isConnected = false);
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _connectWebSocket();
    });
  }

  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'message':
          final msg = ChatMessage.fromJson(json['data'] as Map<String, dynamic>);
          setState(() {
            _messages.add(msg);
            // Auto-disappear if disappearing message
            if (msg.disappearing) {
              _scheduleDisappear(msg.id);
            }
          });
          _scrollToBottom();
          HapticFeedback.lightImpact();
          break;

        case 'typing':
          setState(() => _partnerTyping = json['is_typing'] as bool? ?? false);
          break;

        case 'read':
          // Mark messages as read
          final readId = json['message_id'] as String?;
          if (readId != null) {
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == readId);
              if (idx >= 0) {
                _messages[idx] = _messages[idx].copyWith(isRead: true);
              }
            });
          }
          break;

        case 'message_opened':
          // Disappearing message opened — start timer
          final msgId = json['message_id'] as String?;
          if (msgId != null) _scheduleDisappear(msgId);
          break;
      }
    } catch (e) {
      debugPrint('Message parse error: $e');
    }
  }

  void _scheduleDisappear(String messageId) {
    Future.delayed(
      const Duration(seconds: AppConstants.disappearingMessageSeconds),
      () {
        if (mounted) {
          setState(() => _messages.removeWhere((m) => m.id == messageId));
        }
      },
    );
  }

  void _sendMessage({String? text, String? mediaPath, String? mediaType}) {
    if (!_isConnected) return;
    if (text == null && mediaPath == null) return;
    if (text != null && text.trim().isEmpty) return;

    final message = {
      'type': 'message',
      'data': {
        'text': text,
        'media_path': mediaPath,
        'media_type': mediaType,
        'disappearing': false,
        'timestamp': DateTime.now().toIso8601String(),
      },
    };

    _channel?.sink.add(jsonEncode(message));
    _textController.clear();

    // Optimistic UI
    final localMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: LocalStorage.getString('user_id') ?? '',
      text: text,
      timestamp: DateTime.now(),
      isMine: true,
      isRead: false,
      disappearing: false,
    );

    setState(() => _messages.add(localMsg));
    _scrollToBottom();
    HapticFeedback.selectionClick();
  }

  void _sendDisappearingMessage(String text) {
    if (!_isConnected || text.trim().isEmpty) return;

    final message = {
      'type': 'message',
      'data': {
        'text': text,
        'disappearing': true,
        'timestamp': DateTime.now().toIso8601String(),
      },
    };

    _channel?.sink.add(jsonEncode(message));
    _textController.clear();

    final localMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: LocalStorage.getString('user_id') ?? '',
      text: text,
      timestamp: DateTime.now(),
      isMine: true,
      isRead: false,
      disappearing: true,
    );

    setState(() => _messages.add(localMsg));
    _scheduleDisappear(localMsg.id);
    _scrollToBottom();
  }

  void _notifyTyping(bool isTyping) {
    if (isTyping == _isTyping) return;
    _isTyping = isTyping;

    _channel?.sink.add(jsonEncode({
      'type': 'typing',
      'is_typing': isTyping,
    }));
  }

  Future<void> _pickMedia(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      _sendMessage(mediaPath: picked.path, mediaType: 'image');
    }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.sink.close();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _disappearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_partnerTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _partnerTyping) {
                  return _TypingIndicator();
                }
                return _MessageBubble(
                  message: _messages[index],
                  onLongPress: (msg) => _showMessageOptions(msg),
                );
              },
            ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bgDark2,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.pink,
                child: widget.userAvatar != null
                  ? ClipOval(child: Image.network(widget.userAvatar!, fit: BoxFit.cover))
                  : Text(
                      widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.w700),
                    ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? AppColors.success : AppColors.textMuted,
                    border: Border.all(color: AppColors.bgDark2, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.userName,
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600, fontSize: 15)),
              Text(
                _partnerTyping ? 'typing...' : (_isConnected ? 'online' : 'connecting...'),
                style: TextStyle(
                  color: _partnerTyping ? AppColors.pink : AppColors.textSecondary,
                  fontFamily: 'Poppins',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () => _showChatOptions(),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgDark2,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          // Camera quick capture
          GestureDetector(
            onTap: () => _pickMedia(ImageSource.camera),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),

          const SizedBox(width: 10),

          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgDark3,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Send a message...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontFamily: 'Poppins', fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (text) {
                  _notifyTyping(text.isNotEmpty);
                  _typingTimer?.cancel();
                  _typingTimer = Timer(const Duration(seconds: 2), () {
                    _notifyTyping(false);
                  });
                },
                onSubmitted: (text) => _sendMessage(text: text),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Disappearing message or send
          GestureDetector(
            onTap: () {
              final text = _textController.text;
              if (text.trim().isNotEmpty) {
                _sendMessage(text: text);
              }
            },
            onLongPress: () {
              final text = _textController.text;
              if (text.trim().isNotEmpty) {
                _sendDisappearingMessage(text);
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Disappearing message sent'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _OptionTile(icon: Icons.photo_library, label: 'Send Photo', onTap: () {
            Navigator.pop(context);
            _pickMedia(ImageSource.gallery);
          }),
          _OptionTile(icon: Icons.timer, label: 'Disappearing Messages', onTap: () {
            Navigator.pop(context);
          }),
          _OptionTile(icon: Icons.block, label: 'Block User', color: AppColors.error, onTap: () {}),
          _OptionTile(icon: Icons.delete_sweep, label: 'Clear Chat', color: AppColors.error, onTap: () {
            Navigator.pop(context);
            setState(() => _messages.clear());
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (message.text != null)
            _OptionTile(icon: Icons.copy, label: 'Copy', onTap: () {
              Clipboard.setData(ClipboardData(text: message.text!));
              Navigator.pop(context);
            }),
          if (message.isMine)
            _OptionTile(icon: Icons.delete, label: 'Delete', color: AppColors.error, onTap: () {
              setState(() => _messages.remove(message));
              Navigator.pop(context);
            }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubble Widget
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(ChatMessage) onLongPress;

  const _MessageBubble({required this.message, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: message.isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMine) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.pink,
              child: Icon(Icons.person, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => onLongPress(message),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                decoration: BoxDecoration(
                  gradient: message.isMine
                    ? AppColors.primaryGradient
                    : null,
                  color: message.isMine ? null : AppColors.bgCard,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: message.isMine
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                    bottomRight: message.isMine
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                  ),
                  boxShadow: [
                    if (message.disappearing)
                      BoxShadow(
                        color: AppColors.gold.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                  ],
                  border: message.disappearing
                    ? Border.all(color: AppColors.gold.withOpacity(0.5))
                    : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.disappearing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer, color: AppColors.gold, size: 12),
                            const SizedBox(width: 4),
                            Text('Disappearing',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              )),
                          ],
                        ),
                      ),

                    if (message.text != null)
                      Text(
                        message.text!,
                        style: TextStyle(
                          color: message.isMine
                            ? Colors.white
                            : AppColors.textPrimary,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                      ),

                    if (message.mediaPath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(message.mediaPath!),
                          fit: BoxFit.cover,
                          width: 200,
                        ),
                      ),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            color: message.isMine
                              ? Colors.white.withOpacity(0.7)
                              : AppColors.textMuted,
                            fontFamily: 'Poppins',
                            fontSize: 10,
                          ),
                        ),
                        if (message.isMine) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead
                              ? Icons.done_all
                              : Icons.done,
                            size: 12,
                            color: message.isRead
                              ? AppColors.electricBlue
                              : Colors.white.withOpacity(0.5),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ).animate().slideX(
              begin: message.isMine ? 0.3 : -0.3,
              duration: 200.ms,
              curve: Curves.easeOut,
            ).fadeIn(duration: 200.ms),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 36),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                _TypingDot(delay: 0),
                const SizedBox(width: 4),
                _TypingDot(delay: 200),
                const SizedBox(width: 4),
                _TypingDot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.textMuted,
        shape: BoxShape.circle,
      ),
    )
      .animate(onPlay: (c) => c.repeat())
      .moveY(begin: 0, end: -4, delay: Duration(milliseconds: delay), duration: 300.ms)
      .then()
      .moveY(begin: -4, end: 0, duration: 300.ms);
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white),
      title: Text(label,
        style: TextStyle(
          color: color ?? Colors.white,
          fontFamily: 'Poppins',
          fontSize: 15,
        )),
      onTap: onTap,
    );
  }
}
