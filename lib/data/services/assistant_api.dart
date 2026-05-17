import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../domain/models/chat_message.dart';

class AssistantApi {
  const AssistantApi();

  Dio get _dio => ApiClient.instance.dio;

  String get _baseUrl => Env.apiBaseUrl;

  String? get _token =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/assistant/chat',
        data: {'message': message, 'history': _historyPayload(history)},
      );
      return response.data?['reply'] as String? ?? '';
    } on DioException catch (e) {
      throw e.error ?? const ServerException();
    }
  }

  Stream<Map<String, dynamic>> sendMessageStream(
    String message,
    List<ChatMessage> history,
  ) async* {
    final token = _token;
    if (token == null) {
      yield {
        'type': 'error',
        'data': 'No hay sesión activa. Inicia sesión de nuevo.',
      };
      return;
    }

    final uri = Uri.parse('$_baseUrl/api/assistant/chat/stream');

    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'message': message,
        'history': _historyPayload(history),
      });

    late http.StreamedResponse response;
    try {
      response = await request.send();
    } catch (e) {
      yield {
        'type': 'error',
        'data':
            'No se pudo conectar al servidor. Verifica que el backend esté corriendo.',
      };
      return;
    }

    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      if (response.statusCode == 401) {
        yield {
          'type': 'error',
          'data': 'Sesión expirada. Inicia sesión de nuevo.',
        };
      } else {
        yield {
          'type': 'error',
          'data': 'AGROBOT no pudo responder en este momento.',
        };
      }
      return;
    }

    final textStream = response.stream.transform(const Utf8Decoder());

    String buffer = '';
    String currentEvent = 'message';
    final currentData = StringBuffer();

    await for (final chunk in textStream) {
      buffer += chunk;

      while (true) {
        final newlineIndex = buffer.indexOf('\n');
        if (newlineIndex < 0) break;

        var line = buffer.substring(0, newlineIndex);
        buffer = buffer.substring(newlineIndex + 1);

        if (line.endsWith('\r')) {
          line = line.substring(0, line.length - 1);
        }

        if (line.isEmpty) {
          if (currentData.isNotEmpty) {
            final parsed = _parseSseEvent(currentEvent, currentData.toString());
            if (parsed != null) yield parsed;
          }
          currentEvent = 'message';
          currentData.clear();
          continue;
        }

        if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
          continue;
        }

        if (line.startsWith('data:')) {
          var dataPart = line.substring(5);
          if (dataPart.startsWith(' ')) {
            dataPart = dataPart.substring(1);
          }
          if (currentData.isNotEmpty) {
            currentData.write('\n');
          }
          currentData.write(dataPart);
        }
      }
    }

    if (currentData.isNotEmpty) {
      final parsed = _parseSseEvent(currentEvent, currentData.toString());
      if (parsed != null) yield parsed;
    }
  }

  List<Map<String, String>> _historyPayload(List<ChatMessage> history) {
    return history
        .where((m) => !m.isLoading && !m.isStreaming)
        .map(
          (m) => {
            'role': m.author == ChatAuthor.bot ? 'assistant' : 'user',
            'content': m.text,
          },
        )
        .take(10)
        .toList(growable: false);
  }

  Map<String, dynamic>? _parseSseEvent(String event, String data) {
    return switch (event) {
      'token' => {'type': 'token', 'data': data},
      'done' => {'type': 'done'},
      'error' => {'type': 'error', 'data': data},
      'status' => {'type': 'status', 'data': data},
      'suggestions' => _parseSuggestions(data),
      _ => null,
    };
  }

  Map<String, dynamic>? _parseSuggestions(String data) {
    try {
      return {
        'type': 'suggestions',
        'data': List<String>.from(jsonDecode(data)),
      };
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
