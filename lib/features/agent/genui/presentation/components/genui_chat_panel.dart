import 'package:a2ui/core/theme/app_colors.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_bloc.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_event.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_state.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/message_bubble.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/text_composer.dart';
import 'package:a2ui/features/agent/genui/presentation/widgets/task_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

/// Chat panel component containing the message list and text input.
/// Uses GenUI for A2UI protocol handling with individual task tracking.
class GenUiChatPanel extends StatelessWidget {
  /// Creates a [GenUiChatPanel].
  const GenUiChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        debugPrint('🎨 UI REBUILD - GenUiChatPanel');
        debugPrint('🎨 State status: ${state.status}');
        debugPrint('🎨 Messages count: ${state.messages.length}');
        debugPrint('🎨 Tasks count: ${state.tasks.length}');
        debugPrint('🎨 Current context tasks: ${state.currentContextTasks.length}');

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
