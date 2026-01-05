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
    this.messages = const [],
    this.surfaces = const {},
    this.surfaceIds = const ['default'],
    this.currentSurfaceId = 'default',
    this.status = ConnectionStatus.initial,
    this.errorMessage,
  });

  /// The history of the conversation.
  final List<ChatMessage> messages;

  /// A collection of all active UI surfaces, keyed by surface ID.
  final Map<String, dynamic> surfaces;

  /// The ordered list of surface IDs for navigation.
  final List<String> surfaceIds;

  /// The ID of the surface currently in focus.
  final String currentSurfaceId;

  /// The current connection status.
  final ConnectionStatus status;

  /// An optional error message when status is [ConnectionStatus.error].
  final String? errorMessage;

  /// The index of the current surface in the surface IDs list.
  int get currentSurfaceIndex => surfaceIds.indexOf(currentSurfaceId);

  /// Whether navigation to the previous surface is possible.
  bool get canNavigatePrevious => currentSurfaceIndex > 0;

  /// Whether navigation to the next surface is possible.
  bool get canNavigateNext => currentSurfaceIndex < surfaceIds.length - 1;

  /// Creates a copy of this state with the given fields replaced.
  AgentState copyWith({
    List<ChatMessage>? messages,
    Map<String, dynamic>? surfaces,
    List<String>? surfaceIds,
    String? currentSurfaceId,
    ConnectionStatus? status,
    String? errorMessage,
  }) {
    return AgentState(
      messages: messages ?? this.messages,
      surfaces: surfaces ?? this.surfaces,
      surfaceIds: surfaceIds ?? this.surfaceIds,
      currentSurfaceId: currentSurfaceId ?? this.currentSurfaceId,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        surfaces,
        surfaceIds,
        currentSurfaceId,
        status,
        errorMessage,
      ];
}
