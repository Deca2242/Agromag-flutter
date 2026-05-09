import 'package:flutter/material.dart';

enum ChatAuthor { bot, user }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.time,
    this.attachmentTitle,
    this.attachmentSubtitle,
  });

  final String id;
  final ChatAuthor author;
  final String text;
  final String time;
  final String? attachmentTitle;
  final String? attachmentSubtitle;
}
