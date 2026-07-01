import 'package:a2ui/core/theme/app_colors.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_bloc.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_event.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_state.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/message_bubble.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/text_composer.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/task_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Chat panel component containing the message list and text input.
/// Uses GenUI for A2UI protocol handling with individual task tracking.
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
                  child: state.messages.isEmpty && state.tasks.isEmpty
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

  /// Builds chat items including messages and task bubbles.
  ///
  /// A2A Protocol UI Structure:
  /// 1. Conversation Messages (messages list):
  ///    - User messages: "Do X"
  ///    - AI messages: "Done! Here's the result"
  ///
  /// 2. Task Bubbles (tasks map):
  ///    - Show agent's thinking process
  ///    - Display artifacts generated
  ///    - Track task lifecycle states
  ///
  /// Example flow:
  ///   User: "Generate sales report"
  ///   Task 1: Working... [Loading data, Analyzing...]
  ///   Task 1: Completed [Artifacts: report.pdf]
  ///   AI: "Report generated!" (optional - task may complete without message)
  ///
  /// Order (reversed for ListView):
  /// - Each message has its associated task bubbles displayed after it
  /// - Tasks persist across the entire conversation history
  /// - Active tasks from current context appear immediately
  /// - User message
  /// - Tasks for that message (if any)
  /// - Previous messages...
  List<Widget> _buildChatItems(AgentState state) {
    final items = <Widget>[];

    // Reverse messages for display (newest at bottom visually)
    final reversedMessages = state.messages.reversed.toList();

    // Track which contexts we've already displayed
    final displayedContexts = <String>{};

    for (var i = 0; i < reversedMessages.length; i++) {
      final message = reversedMessages[i];

      // Calculate the original index (before reversing)
      final originalIndex = state.messages.length - 1 - i;

      // Add regular message bubble
      items.add(GenUiMessageBubble(message: message));

      // For the most recent message (i == 0), show current context tasks
      // even if not yet mapped (for immediate reactivity)
      if (i == 0 && state.currentContextId != null) {
        final currentTasks = state.currentContextTasks;
        if (currentTasks.isNotEmpty) {
          for (final task in currentTasks) {
            items.add(TaskBubble(task: task));
          }
          displayedContexts.add(state.currentContextId!);
        }
      } else {
        // For older messages, check if this message has associated tasks
        final contextId = state.messageContextMap[originalIndex];
        if (contextId != null && !displayedContexts.contains(contextId)) {
          final messageTasks = state.getTasksForContext(contextId);

          // Add all task bubbles for this message's context
          for (final task in messageTasks) {
            items.add(TaskBubble(task: task));
          }
          displayedContexts.add(contextId);
        }
      }
    }

    // If we have tasks but no messages yet (edge case)
    // This can happen if tasks are created before the first message completes
    if (state.messages.isEmpty && state.currentContextId != null) {
      final contextTasks = state.currentContextTasks;
      for (final task in contextTasks) {
        items.add(TaskBubble(task: task));
      }
    }

    return items;
  }
}
