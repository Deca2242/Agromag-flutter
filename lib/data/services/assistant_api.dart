import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/chat_message.dart';

/// Endpoint POST /api/assistant/chat del backend Spring.
class AssistantApi {
  const AssistantApi();

  Dio get _dio => ApiClient.instance.dio;

  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    try {
      final historyJson = history
          .where((m) => !m.isLoading)
          .map(
            (m) => {
              'role': m.author == ChatAuthor.bot ? 'assistant' : 'user',
              'content': m.text,
            },
          )
          .toList();

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/assistant/chat',
        data: {'message': message, 'history': historyJson},
      );
      return response.data?['reply'] as String? ?? '';
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }
}
