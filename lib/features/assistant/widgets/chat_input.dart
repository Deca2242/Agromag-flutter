import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({super.key, this.onSend, this.enabled = true});

  final ValueChanged<String>? onSend;
  final bool enabled;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? AppColors.surface
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  textInputAction: TextInputAction.send,
                  onSubmitted: widget.enabled ? (_) => _handleSend() : null,
                  decoration: InputDecoration(
                    hintText: widget.enabled
                        ? 'Escribe tu consulta aquí...'
                        : 'Asistente no disponible sin conexión',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.enabled
                    ? AppColors.primaryGreen
                    : AppColors.divider,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: widget.enabled ? _handleSend : null,
                tooltip: 'Enviar mensaje',
                icon: Icon(
                  Icons.send,
                  color: widget.enabled ? Colors.white : AppColors.textMuted,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
