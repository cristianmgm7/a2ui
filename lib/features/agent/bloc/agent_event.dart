import 'package:equatable/equatable.dart';
import 'package:genui/genui.dart';

/// Base class for all Agent events.
sealed class AgentEvent extends Equatable {
  const AgentEvent();

  @override
  List<Object?> get props => [];
}

/// Event to initialize the agent and set up connections.
class InitializeAgent extends AgentEvent {
  const InitializeAgent();
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

/// Event triggered when the protocol receives an update.
class OnProtocolUpdate extends AgentEvent {
  /// Creates an [OnProtocolUpdate] event.
  const OnProtocolUpdate(this.update);

  /// The update from the GenUI protocol.
  final GenUiUpdate update;

  @override
  List<Object?> get props => [update];
}

/// Event triggered when messages in the conversation change.
class OnMessagesUpdated extends AgentEvent {
  /// Creates an [OnMessagesUpdated] event.
  const OnMessagesUpdated(this.messages);

  /// The updated list of messages.
  final List<ChatMessage> messages;

  @override
  List<Object?> get props => [messages];
}

/// Event to switch to a specific surface by ID.
class SwitchSurface extends AgentEvent {
  /// Creates a [SwitchSurface] event.
  const SwitchSurface(this.surfaceId);

  /// The ID of the surface to switch to.
  final String surfaceId;

  @override
  List<Object?> get props => [surfaceId];
}

/// Event to navigate to the next surface.
class NextSurface extends AgentEvent {
  const NextSurface();
}

/// Event to navigate to the previous surface.
class PreviousSurface extends AgentEvent {
  const PreviousSurface();
}
