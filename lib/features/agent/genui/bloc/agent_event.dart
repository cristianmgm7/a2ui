import 'package:equatable/equatable.dart';

/// Base class for all Agent events.
sealed class AgentEvent extends Equatable {
  const AgentEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize the agent and set up connections.
class InitializeAgent extends AgentEvent {
  const InitializeAgent({this.sessionId});

  /// Optional session ID to restore a previous session
  final String? sessionId;

  @override
  List<Object?> get props => [sessionId];
}

/// Event to send a message to the agent.
class SendMessage extends AgentEvent {
  /// Creates a [SendMessage] event.
  const SendMessage(this.text);

  /// The message text to send.
  final String text;

  @override
  List<Object?> get props => [text];
}
