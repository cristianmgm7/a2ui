import 'package:flutter/material.dart';
import 'package:genui/genui.dart' as genui;
import 'package:genui_a2ui/genui_a2ui.dart';
import 'package:logging/logging.dart';

// Simple chat message model for backward compatibility
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

void main() {
  // Initialize logging for GenUI
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const GenUIExampleApp());
}

class GenUIExampleApp extends StatelessWidget {
  const GenUIExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2UI Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];

  // Agent server configuration
  // For development: try different addresses based on platform
  // iOS Simulator: use 127.0.0.1 (special loopback to host)
  // Android Emulator: use 10.0.2.2
  // Physical devices: use host machine IP (192.168.1.33)
  static const String _agentServerHost = '127.0.0.1';
  static const int _agentServerPort = 8000;

  // GenUI components
  late genui.GenUiConversation _conversation;
  late A2uiContentGenerator _contentGenerator;
  late genui.A2uiMessageProcessor _messageProcessor;

  @override
  void initState() {
    super.initState();

    // Initialize GenUI content generator pointing to the Python agent
    // For testing: try localhost first, then fall back to network IP
    _contentGenerator = A2uiContentGenerator(
      serverUrl: Uri.parse('http://localhost:$_agentServerPort'),
    );

    // Create the message processor with core catalog
    _messageProcessor = genui.A2uiMessageProcessor(
      catalogs: [genui.CoreCatalogItems.asCatalog()],
    );

    // Create the GenUI conversation
    _conversation = genui.GenUiConversation(
      contentGenerator: _contentGenerator,
      a2uiMessageProcessor: _messageProcessor,
      onTextResponse: (text) {
        setState(() {
          _messages.add(ChatMessage(text: text, isUser: false));
        });
      },
      onError: (error) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Error: ${error.error}',
            isUser: false
          ));
        });
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _conversation.dispose();
    _contentGenerator.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();

    final userMessage = genui.UserMessage.text(text);

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true));
    });

    // Send message through GenUI conversation
    _conversation.sendRequest(userMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A2UI Example (Simplified)'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: <Widget>[
          // Status bar showing A2A integration status
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.green.shade100,
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A2A integration enabled. Connected to Python agent backend.',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Chat messages area
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemBuilder: (_, int index) => _buildMessage(_messages[index]),
              itemCount: _messages.length,
            ),
          ),
          const Divider(height: 1.0),
          // Input area
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
          // AI-generated UI area using GenUI
          Container(
            height: 300,
            color: Colors.grey.shade50,
            child: genui.GenUiSurface(
              host: _messageProcessor,
              surfaceId: 'main_surface',
              defaultBuilder: (context) => const Center(
                child: Text('Waiting for AI-generated UI...'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              child: Text(message.isUser ? 'U' : 'A'),
              backgroundColor: message.isUser ? Colors.blue : Colors.green,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.isUser ? 'User' : 'AI Assistant',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: Text(message.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
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
                decoration:
                    const InputDecoration.collapsed(hintText: 'Send a message'),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _handleSubmitted(_textController.text)),
            ),
          ],
        ),
      ),
    );
  }
}