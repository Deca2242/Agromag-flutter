import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_chat.dart';
import '../../domain/models/chat_message.dart';

final chatMessagesProvider =
    Provider<List<ChatMessage>>((ref) => kMockChat);

final chatSuggestionsProvider =
    Provider<List<String>>((ref) => kChatSuggestions);
