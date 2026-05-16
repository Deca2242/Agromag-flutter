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
    this.isStreaming = false,
    this.suggestions = const [],
  });

  final String id;
  final ChatAuthor author;
  final String text;
  final String time;
  final String? attachmentTitle;
  final String? attachmentSubtitle;

  final bool isLoading;
  final bool isError;
  final bool isStreaming;
  final List<String> suggestions;

  ChatMessage copyWith({
    String? text,
    bool? isLoading,
    bool? isError,
    bool? isStreaming,
    List<String>? suggestions,
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
      isStreaming: isStreaming ?? this.isStreaming,
      suggestions: suggestions ?? this.suggestions,
    );
  }
}
