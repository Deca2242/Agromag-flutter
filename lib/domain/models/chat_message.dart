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
    this.isLoading = false,
    this.isError = false,
  });

  final String id;
  final ChatAuthor author;
  final String text;
  final String time;
  final String? attachmentTitle;
  final String? attachmentSubtitle;
  /// True while waiting for the bot's response.
  final bool isLoading;
  /// True when the request failed.
  final bool isError;

  ChatMessage copyWith({
    String? text,
    bool? isLoading,
    bool? isError,
  }) {
    return ChatMessage(
      id: id,
      author: author,
      text: text ?? this.text,
      time: time,
      attachmentTitle: attachmentTitle,
      attachmentSubtitle: attachmentSubtitle,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
    );
  }
}
