import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/assistant_repository.dart';
import '../../data/services/assistant_api.dart';
import '../../domain/models/chat_message.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(api: const AssistantApi());
});

List<ChatMessage> _initialMessages() => [
  ChatMessage(
    id: '0',
    author: ChatAuthor.bot,
    text:
        '¡Hola! Soy AGROBOT, tu asistente agrícola impulsado por DeepSeek vía OpenRouter. '
        'Puedo ayudarte con tus cultivos registrados, alertas, recomendaciones, clima, '
        'riego, plagas, fertilización u otras labores.',
    time: DateFormat('hh:mm a').format(DateTime.now()),
  ),
];

class ChatNotifier extends Notifier<List<ChatMessage>> {
  AssistantRepository get _repo => ref.read(assistantRepositoryProvider);

  List<String> _suggestions = [];
  List<String> get suggestions => _suggestions;

  @override
  List<ChatMessage> build() => _initialMessages();

  bool get isWaiting => state.any((m) => m.isLoading || m.isStreaming);

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || isWaiting) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: ChatAuthor.user,
      text: text.trim(),
      time: DateFormat('hh:mm a').format(DateTime.now()),
    );

    final loadingMsg = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_loading',
      author: ChatAuthor.bot,
      text: '',
      time: '',
      isLoading: true,
    );

    state = [...state, userMsg, loadingMsg];

    try {
      final reply = await _repo.sendMessage(text.trim(), state);
      state = [...state.where((m) => !m.isLoading), reply];
    } catch (e) {
      if (kDebugMode) print('[Chat] Error sendMessage: $e');
      final errorMsg = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        author: ChatAuthor.bot,
        text: 'No se pudo conectar al asistente. Intenta de nuevo.',
        time: DateFormat('hh:mm a').format(DateTime.now()),
        isError: true,
      );
      state = [...state.where((m) => !m.isLoading), errorMsg];
    }
  }

  Future<void> sendStreamMessage(String text) async {
    if (text.trim().isEmpty || isWaiting) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: ChatAuthor.user,
      text: text.trim(),
      time: DateFormat('hh:mm a').format(DateTime.now()),
    );

    final streamId = '${DateTime.now().millisecondsSinceEpoch}_stream';
    final streamingMsg = ChatMessage(
      id: streamId,
      author: ChatAuthor.bot,
      text: '',
      time: DateFormat('hh:mm a').format(DateTime.now()),
      isStreaming: true,
    );

    state = [...state, userMsg, streamingMsg];

    final accumulatedText = StringBuffer();
    List<String> newSuggestions = [];

    try {
      await for (final event in _repo.sendMessageStream(text.trim(), state)) {
        if (kDebugMode) print('[Chat SSE] Event: ${event['type']}');

        switch (event['type']) {
          case 'token':
            accumulatedText.write(event['data']);
            state = [
              ...state.where((m) => m.id != streamId),
              streamingMsg.copyWith(text: accumulatedText.toString()),
            ];
            break;

          case 'suggestions':
            newSuggestions = List<String>.from(event['data']);
            break;

          case 'done':
            _suggestions = newSuggestions;
            final finalMsg = ChatMessage(
              id: streamId,
              author: ChatAuthor.bot,
              text: accumulatedText.toString(),
              time: DateFormat('hh:mm a').format(DateTime.now()),
              isStreaming: false,
              suggestions: newSuggestions,
            );
            state = [...state.where((m) => m.id != streamId), finalMsg];
            return;

          case 'error':
            final errorMsg = ChatMessage(
              id: '${DateTime.now().millisecondsSinceEpoch}_err',
              author: ChatAuthor.bot,
              text: event['data'] ?? 'Error del asistente.',
              time: DateFormat('hh:mm a').format(DateTime.now()),
              isError: true,
            );
            state = [...state.where((m) => m.id != streamId), errorMsg];
            return;
        }
      }

      if (accumulatedText.isNotEmpty) {
        final finalMsg = ChatMessage(
          id: streamId,
          author: ChatAuthor.bot,
          text: accumulatedText.toString(),
          time: DateFormat('hh:mm a').format(DateTime.now()),
          isStreaming: false,
          suggestions: newSuggestions,
        );
        state = [...state.where((m) => m.id != streamId), finalMsg];
      }
    } catch (e) {
      if (kDebugMode) print('[Chat SSE] Error: $e');
      final errorMsg = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_err',
        author: ChatAuthor.bot,
        text: 'No se pudo conectar al asistente. Intenta de nuevo.',
        time: DateFormat('hh:mm a').format(DateTime.now()),
        isError: true,
      );
      state = [...state.where((m) => m.id != streamId), errorMsg];
    }
  }

  void clearHistory() {
    _suggestions = [];
    state = _initialMessages();
  }

  void useSuggestion(String suggestion) {
    sendStreamMessage(suggestion);
  }
}

final chatMessagesProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);
