import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/chat_message.dart';
import 'forecast_attachment_card.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.author == ChatAuthor.user;
    final bubbleColor = isUser ? AppColors.primaryGreenDark : Colors.white;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * (isUser ? 0.76 : 0.84);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 16),
    );

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[
          Row(
            children: const [
              Icon(
                Icons.smart_toy_outlined,
                size: 14,
                color: AppColors.primaryGreen,
              ),
              SizedBox(width: 4),
              Text(
                'AGROBOT',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Align(
          alignment: align,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: radius,
                border: isUser ? null : Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (message.isStreaming)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            message.text,
                            style: TextStyle(
                              color: message.isError ? AppColors.alertRed : textColor,
                              height: 1.42,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const _BlinkingCursor(),
                      ],
                    )
                  else
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isError ? AppColors.alertRed : textColor,
                        height: 1.42,
                        fontSize: 14,
                      ),
                    ),
                  if (message.attachmentTitle != null) ...[
                    const SizedBox(height: 12),
                    ForecastAttachmentCard(
                      title: message.attachmentTitle!,
                      subtitle: message.attachmentSubtitle ?? '',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message.time,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: const Text(
        '▎',
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
