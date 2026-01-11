import 'package:a2ui/core/theme/app_colors.dart';
import 'package:a2ui/core/theme/app_text_style.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

/// A bubble widget that displays a chat message with Carbon Voice styling.
class GenUiMessageBubble extends StatelessWidget {
  /// Creates a [GenUiMessageBubble].
  const GenUiMessageBubble({
    required this.message,
    super.key,
  });

  /// The message to display.
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUserMessage = message is UserMessage;
    var text = '';
    if (message is UserMessage) {
      text = (message as UserMessage).text;
    } else if (message is AiTextMessage) {
      text = (message as AiTextMessage).text;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          if (!isUserMessage) ...[
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                'A',
                style: AppTextStyle.bodyMedium.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUserMessage ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isUserMessage
                      ? AppColors.primary
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Column(
                children: <Widget>[
                  if (!isUserMessage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Agent',
                        style: AppTextStyle.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: AppTextStyle.bodyMedium.copyWith(
                      color: isUserMessage
                          ? AppColors.onPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUserMessage) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: AppColors.accent,
              child: Text(
                'U',
                style: AppTextStyle.bodyMedium.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
