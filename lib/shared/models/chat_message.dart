// lib/shared/models/chat_message.dart
class ChatMessage {
  final String id;
  final String senderId;
  final String? text;
  final String? mediaPath;
  final String? mediaType;
  final DateTime timestamp;
  final bool isMine;
  final bool isRead;
  final bool disappearing;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.mediaPath,
    this.mediaType,
    required this.timestamp,
    required this.isMine,
    required this.isRead,
    required this.disappearing,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      text: json['text'] as String?,
      mediaPath: json['media_path'] as String?,
      mediaType: json['media_type'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isMine: json['is_mine'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? false,
      disappearing: json['disappearing'] as bool? ?? false,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? text,
    String? mediaPath,
    String? mediaType,
    DateTime? timestamp,
    bool? isMine,
    bool? isRead,
    bool? disappearing,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      timestamp: timestamp ?? this.timestamp,
      isMine: isMine ?? this.isMine,
      isRead: isRead ?? this.isRead,
      disappearing: disappearing ?? this.disappearing,
    );
  }
}
