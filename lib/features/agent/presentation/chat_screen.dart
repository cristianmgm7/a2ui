import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

import '../bloc/agent_bloc.dart';
import '../bloc/agent_event.dart';
import '../bloc/agent_state.dart';

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
          appBar: _buildAppBar(context, state),
          body: Row(
            children: <Widget>[
              _buildChatPanel(context, state),
              _buildSurfacePanel(context, state),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AgentState state) {
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
  }

  Widget _buildChatPanel(BuildContext context, AgentState state) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemBuilder: (_, int index) =>
                  _buildMessage(state.messages.reversed.toList()[index]),
              itemCount: state.messages.length,
            ),
          ),
          const Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _TextComposer(
              onSubmitted: (text) {
                context.read<AgentBloc>().add(SendMessage(text));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurfacePanel(BuildContext context, AgentState state) {
    final agentBloc = context.read<AgentBloc>();
    return Expanded(
      child: SingleChildScrollView(
        child: GenUiSurface(
          key: ValueKey(state.currentSurfaceId),
          host: agentBloc.messageProcessor,
          surfaceId: state.currentSurfaceId,
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isUserMessage = message is UserMessage;
    var text = '';
    if (message is UserMessage) {
      text = message.text;
    } else if (message is AiTextMessage) {
      text = message.text;
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(child: Text(isUserMessage ? 'U' : 'A')),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isUserMessage ? 'User' : 'Agent',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: Text(text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Text input composer widget.
class _TextComposer extends StatefulWidget {
  const _TextComposer({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  State<_TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<_TextComposer> {
  final TextEditingController _textController = TextEditingController();

  void _handleSubmitted(String text) {
    _textController.clear();
    widget.onSubmitted(text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Send a message',
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
