import 'package:intl/intl.dart';

import '../../domain/models/chat_message.dart';
import '../services/assistant_api.dart';

/// Mantiene el historial de mensajes en memoria y delega al API.
class AssistantRepository {
  AssistantRepository({required AssistantApi api}) : _api = api;

  final AssistantApi _api;

  Future<ChatMessage> sendMessage(
      String text, List<ChatMessage> history) async {
    final reply = await _api.sendMessage(text, history);
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: ChatAuthor.bot,
      text: reply,
      time: DateFormat('hh:mm a').format(DateTime.now()),
    );
  }
}
