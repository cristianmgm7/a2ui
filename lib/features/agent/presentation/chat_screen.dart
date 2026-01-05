import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/agent_bloc.dart';
import '../bloc/agent_state.dart';
import 'components/chat_app_bar.dart';
import 'components/chat_panel.dart';
import 'components/surface_panel.dart';

/// The main chat screen using BLoC architecture.
class ChatScreen extends StatelessWidget {
  /// Creates a [ChatScreen].
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        if (state.surfaceIds.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('A2UI Example')),
            body: const Center(child: Text('No surfaces available.')),
          );
        }

        return Scaffold(
          appBar: const ChatAppBar(),
          body: Row(
            children: const <Widget>[
              ChatPanel(),
              SurfacePanel(),
            ],
          ),
        );
      },
    );
  }
}
