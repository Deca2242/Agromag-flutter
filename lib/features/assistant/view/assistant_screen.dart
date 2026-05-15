import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/chat_message.dart';
import '../../../core/widgets/adaptive_body.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../home/home_providers.dart';
import '../assistant_providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';

class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final isWaiting = notifier.isWaiting;

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
              if (!isOnline)
                Container(
                  width: double.infinity,
                  color: AppColors.alertRed.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 16,
                        color: AppColors.alertRed,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El asistente requiere conexión a internet.',
                          style: TextStyle(
                            color: AppColors.alertRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _MessagesList(messages: messages)),
              ChatInput(
                enabled: isOnline && !isWaiting,
                onSend: notifier.sendMessage,
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
    if (widget.messages.length != oldWidget.messages.length) {
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
