import 'package:a2ui/core/theme/app_colors.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_bloc.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_event.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_state.dart';
import 'package:a2ui/features/agent/genui/presentation/components/genui_chat_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Main GenUI-based Agent Chat Screen.
///
/// This replaces the old agent_chat_screen.dart which used custom DTOs and repositories.
/// Now using GenUI's A2UI protocol for automatic UI generation from the backend agent.
class GenUiAgentChatScreen extends StatelessWidget {
  /// Creates a [GenUiAgentChatScreen].
  const GenUiAgentChatScreen({
    this.sessionId,
    super.key,
  });

  /// Optional session ID to restore a previous chat session.
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AgentBloc(
        sessionId: sessionId,
      )..add(InitializeAgent(sessionId: sessionId)),
      child: const _GenUiAgentChatView(),
    );
  }
}

class _GenUiAgentChatView extends StatelessWidget {
  const _GenUiAgentChatView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Agent Chat (GenUI)'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      body: BlocBuilder<AgentBloc, AgentState>(
        builder: (context, state) {
          // Show error state
          if (state.status == ConnectionStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connection Error',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      state.errorMessage ?? 'Failed to connect to agent',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<AgentBloc>().add(
                            InitializeAgent(sessionId: state.sessionId),
                          );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Show loading state
          if (state.status == ConnectionStatus.loading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Connecting to agent...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Main chat UI - two-column layout
          return const GenUiChatPanel();
        },
      ),
    );
  }
}
