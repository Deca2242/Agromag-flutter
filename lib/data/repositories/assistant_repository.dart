import 'package:intl/intl.dart';

import '../../domain/models/chat_message.dart';
import '../services/assistant_api.dart';

class AssistantRepository {
  AssistantRepository({required AssistantApi api}) : _api = api;

  final AssistantApi _api;

  Future<ChatMessage> sendMessage(
    String text,
    List<ChatMessage> history,
  ) async {
    final reply = await _api.sendMessage(text, history);
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: ChatAuthor.bot,
      text: reply,
      time: DateFormat('hh:mm a').format(DateTime.now()),
    );
  }

  Stream<Map<String, dynamic>> sendMessageStream(
    String text,
    List<ChatMessage> history,
  ) {
    return _api.sendMessageStream(text, history);
  }
}
