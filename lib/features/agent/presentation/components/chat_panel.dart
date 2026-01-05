import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/agent_bloc.dart';
import '../../bloc/agent_event.dart';
import '../../bloc/agent_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/text_composer.dart';

/// Chat panel component containing the message list and text input.
class ChatPanel extends StatelessWidget {
  /// Creates a [ChatPanel].
  const ChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  reverse: true,
                  itemBuilder: (_, int index) =>
                      MessageBubble(message: state.messages.reversed.toList()[index]),
                  itemCount: state.messages.length,
                ),
              ),
              const Divider(height: 1.0),
              Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor),
                child: TextComposer(
                  onSubmitted: (text) {
                    context.read<AgentBloc>().add(SendMessage(text));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
