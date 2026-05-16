import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/assistant_repository.dart';
import '../../data/services/assistant_api.dart';
import '../../domain/models/chat_message.dart';

// ── Repositorio ────────────────────────────────────────────────────────────

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(api: const AssistantApi());
});

// ── Chat state ─────────────────────────────────────────────────────────────

List<ChatMessage> _initialMessages() => [
  ChatMessage(
    id: '0',
    author: ChatAuthor.bot,
    text:
        '¡Hola! Soy tu asistente agrícola. Tengo contexto de tus cultivos '
        'registrados en la app. Pregúntame sobre riego, plagas, fertilización '
        'u otras labores.',
    time: DateFormat('hh:mm a').format(DateTime.now()),
  ),
];

class ChatNotifier extends Notifier<List<ChatMessage>> {
  AssistantRepository get _repo => ref.read(assistantRepositoryProvider);

  @override
  List<ChatMessage> build() => _initialMessages();

  /// Returns true if there's a loading placeholder in the state.
  bool get isWaiting => state.any((m) => m.isLoading);

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
    } catch (_) {
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

  void clearHistory() {
    state = _initialMessages();
  }
}

final chatMessagesProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);
