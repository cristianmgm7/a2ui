import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

import '../../bloc/agent_bloc.dart';
import '../../bloc/agent_state.dart';

/// Surface panel component that displays the GenUiSurface.
class SurfacePanel extends StatelessWidget {
  /// Creates a [SurfacePanel].
  const SurfacePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        final agentBloc = context.read<AgentBloc>();

        // Don't render GenUiSurface until the message processor is initialized
        if (agentBloc.messageProcessor == null) {
          return const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Expanded(
          child: SingleChildScrollView(
            child: GenUiSurface(
              key: ValueKey(state.currentSurfaceId),
              host: agentBloc.messageProcessor!,
              surfaceId: state.currentSurfaceId,
            ),
          ),
        );
      },
    );
  }
}
