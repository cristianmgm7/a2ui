import 'package:a2ui/features/agent/genui/models/thinking_step.dart';
import 'package:equatable/equatable.dart';
import 'package:genui/genui.dart';

/// Represents the connection status of the agent.
enum ConnectionStatus {
  /// Initial state, not yet connected.
  initial,

  /// Loading/connecting state.
  loading,

  /// Streaming data from the agent.
  streaming,

  /// An error occurred.
  error,
}

/// The state of the Agent BLoC.
class AgentState extends Equatable {
  /// Creates an [AgentState].
  const AgentState({
    this.sessionId,
    this.messages = const [],
    this.status = ConnectionStatus.initial,
    this.errorMessage,
    this.currentThinkingSteps = const [],
    this.isThinking = false,
    this.thinkingError,
  });

  /// The current session ID (for session management)
  final String? sessionId;

  /// The history of the conversation.
  final List<ChatMessage> messages;

  /// The current connection status.
  final ConnectionStatus status;

  /// An optional error message when status is [ConnectionStatus.error].
  final String? errorMessage;

  /// Tracks agent's thinking/progress steps
  final List<ThinkingStep> currentThinkingSteps;

  /// Whether agent is currently in thinking state
  final bool isThinking;

  /// Error that occurred during thinking (if any)
  final String? thinkingError;

  /// Creates a copy of this state with the given fields replaced.
  AgentState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    ConnectionStatus? status,
    String? errorMessage,
    List<ThinkingStep>? currentThinkingSteps,
    bool? isThinking,
    String? thinkingError,
  }) {
    return AgentState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentThinkingSteps: currentThinkingSteps ?? this.currentThinkingSteps,
      isThinking: isThinking ?? this.isThinking,
      thinkingError: thinkingError ?? this.thinkingError,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        messages,
        status,
        errorMessage,
        currentThinkingSteps,
        isThinking,
        thinkingError,
      ];
}
