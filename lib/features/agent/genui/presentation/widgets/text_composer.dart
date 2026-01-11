import 'package:a2ui/core/theme/app_colors.dart';
import 'package:a2ui/core/theme/app_text_style.dart';
import 'package:flutter/material.dart';

/// Text input composer widget for sending messages with Carbon Voice styling.
class GenUiTextComposer extends StatefulWidget {
  /// Creates a [GenUiTextComposer].
  const GenUiTextComposer({
    required this.onSubmitted,
    this.isLoading = false,
    super.key,
  });

  /// Callback when the user submits text.
  final ValueChanged<String> onSubmitted;

  /// Whether the agent is currently processing a message.
  final bool isLoading;

  @override
  State<GenUiTextComposer> createState() => _GenUiTextComposerState();
}

class _GenUiTextComposerState extends State<GenUiTextComposer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty || widget.isLoading) return;

    _textController.clear();
    widget.onSubmitted(text);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              enabled: !widget.isLoading,
              onSubmitted: _handleSubmitted,
              decoration: InputDecoration(
                hintText: widget.isLoading
                    ? 'Agent is thinking...'
                    : 'Type your message...',
                hintStyle: AppTextStyle.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              style: AppTextStyle.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: widget.isLoading ? AppColors.border : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                widget.isLoading ? Icons.hourglass_empty : Icons.send,
                color: AppColors.onPrimary,
              ),
              onPressed: widget.isLoading
                  ? null
                  : () => _handleSubmitted(_textController.text),
            ),
          ),
        ],
      ),
    );
  }
}
