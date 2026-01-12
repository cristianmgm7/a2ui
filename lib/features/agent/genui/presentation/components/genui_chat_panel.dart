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
  /// - Task bubbles (shown after most recent message)
  /// - AI message (if exists)
  /// - User message
  /// - Previous messages...
  List<Widget> _buildChatItems(AgentState state) {
    final items = <Widget>[];

    // Reverse messages for display (newest at bottom visually)
    final reversedMessages = state.messages.reversed.toList();

    // Get current context tasks
    final contextTasks = state.currentContextTasks;

    // Track if we've added the task bubbles
    bool taskBubblesAdded = false;

    for (var i = 0; i < reversedMessages.length; i++) {
      final message = reversedMessages[i];

      // Add regular message bubble
      items.add(GenUiMessageBubble(message: message));

      // Show task bubbles after the most recent message if:
      // 1. We haven't added them yet
      // 2. We have tasks for this context
      // 3. This is the most recent message (i == 0)
      if (!taskBubblesAdded && i == 0 && contextTasks.isNotEmpty) {
        // Add all task bubbles for this context (in chronological order)
        for (final task in contextTasks) {
          items.add(TaskBubble(task: task));
        }
        taskBubblesAdded = true;
      }
    }

    // If we have tasks but no messages yet (edge case)
    if (state.messages.isEmpty && contextTasks.isNotEmpty) {
      for (final task in contextTasks) {
        items.add(TaskBubble(task: task));
      }
    }

    return items;
  }
}
