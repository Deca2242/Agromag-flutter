import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/chat_message.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../assistant_providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';

class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);
    final isWaiting = notifier.isWaiting;
    final suggestions = notifier.suggestions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            BrandLogo(size: 24),
            SizedBox(width: 8),
            Text(
              'Asistente IA',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => notifier.clearHistory(),
            tooltip: 'Nueva conversación',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AdaptiveBody(
          child: Column(
            children: [
              Expanded(child: _MessagesList(messages: messages)),
              if (suggestions.isNotEmpty)
                _SuggestionChips(
                  suggestions: suggestions,
                  onTap: notifier.useSuggestion,
                ),
              ChatInput(
                enabled: !isWaiting,
                disabledHintText: 'AGROBOT está respondiendo...',
                onSend: notifier.sendStreamMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesList extends StatefulWidget {
  const _MessagesList({required this.messages});

  final List<ChatMessage> messages;

  @override
  State<_MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<_MessagesList> {
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(_MessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldScroll(oldWidget.messages, widget.messages)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  bool _shouldScroll(List<ChatMessage> oldMessages, List<ChatMessage> messages) {
    if (messages.length != oldMessages.length) {
      return true;
    }
    if (messages.isEmpty || oldMessages.isEmpty) {
      return false;
    }
    final last = messages.last;
    final oldLast = oldMessages.last;
    return last.id == oldLast.id && last.text != oldLast.text;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    return ListView.separated(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return ChatBubble(message: messages[index]);
      },
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: const BoxConstraints(maxHeight: 60),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return FilterChip(
            label: Text(suggestions[index]),
            onSelected: (_) => onTap(suggestions[index]),
            backgroundColor: AppColors.background,
            selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
            side: BorderSide(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
            labelStyle: const TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}
