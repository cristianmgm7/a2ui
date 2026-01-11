import 'package:a2ui/core/theme/app_colors.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_bloc.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_event.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_state.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/message_bubble.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/text_composer.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/thinking_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

/// Chat panel component containing the message list and text input.
/// Uses GenUI for A2UI protocol handling.
class GenUiChatPanel extends StatelessWidget {
  /// Creates a [GenUiChatPanel].
  const GenUiChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        final isStreaming = state.status == ConnectionStatus.streaming;

        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 300, maxWidth: 600),
          child: ColoredBox(
            color: AppColors.background,
            child: Column(
              children: <Widget>[
                // Messages list
                Expanded(
                  child: state.messages.isEmpty && !state.isThinking
                      ? const Center(
                          child: Text(
                            'Start a conversation with the agent',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          reverse: true,
                          itemBuilder: (_, int index) {
                            final items = _buildChatItems(state);
                            return items[index];
                          },
                          itemCount: _buildChatItems(state).length,
                        ),
                ),

                // Divider
                const Divider(height: 1, color: AppColors.border),

                // Text input
                GenUiTextComposer(
                  onSubmitted: (text) {
                    context.read<AgentBloc>().add(SendMessage(text));
                  },
                  isLoading: isStreaming,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds chat items including messages and thinking bubble.
  ///
  /// Order (reversed for ListView):
  /// - Final AI message (if exists)
  /// - Thinking bubble (if active or has steps)
  /// - User message
  /// - Previous messages...
  List<Widget> _buildChatItems(AgentState state) {
    final items = <Widget>[];

    // Reverse messages for display (newest at bottom visually)
    final reversedMessages = state.messages.reversed.toList();

    for (var i = 0; i < reversedMessages.length; i++) {
      final message = reversedMessages[i];

      // Add regular message bubble
      items.add(GenUiMessageBubble(message: message));

      // If this is the most recent user message and we're thinking,
      // insert the thinking bubble after it
      if (i == 0 && // Most recent message
          message is UserMessage && // It's a user message
          (state.isThinking || state.currentThinkingSteps.isNotEmpty)) {
        items.add(
          ThinkingBubble(
            thinkingSteps: state.currentThinkingSteps,
            isActive: state.isThinking,
            error: state.thinkingError,
          ),
        );
      }
    }

    // If thinking but no messages yet (edge case)
    if (state.messages.isEmpty && state.isThinking) {
      items.add(
        ThinkingBubble(
          thinkingSteps: state.currentThinkingSteps,
          isActive: state.isThinking,
          error: state.thinkingError,
        ),
      );
    }

    return items;
  }
}
