import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

/// A bubble widget that displays a chat message.
class MessageBubble extends StatelessWidget {
  /// Creates a [MessageBubble].
  const MessageBubble({
    super.key,
    required this.message,
  });

  /// The message to display.
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUserMessage = message is UserMessage;
    var text = '';
    if (message is UserMessage) {
      text = (message as UserMessage).text;
    } else if (message is AiTextMessage) {
      text = (message as AiTextMessage).text;
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
