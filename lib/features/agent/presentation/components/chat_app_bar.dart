import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/agent_bloc.dart';
import '../../bloc/agent_event.dart';
import '../../bloc/agent_state.dart';

/// App bar component for the chat screen with navigation controls.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a [ChatAppBar].
  const ChatAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        return AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.read<AgentBloc>().add(const PreviousSurface()),
            tooltip: 'Previous Surface',
            color: state.canNavigatePrevious
                ? null
                : Theme.of(context).disabledColor,
          ),
          title: Text('Surface: ${state.currentSurfaceId}'),
          actions: [
            if (state.status == ConnectionStatus.streaming)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => context.read<AgentBloc>().add(const NextSurface()),
              tooltip: 'Next Surface',
              color: state.canNavigateNext ? null : Theme.of(context).disabledColor,
            ),
          ],
        );
      },
    );
  }
}
