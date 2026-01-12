import 'package:a2ui/features/agent/genui/models/task_info.dart';
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
    this.tasks = const {},
    this.currentContextId,
  });

  /// The current session ID (for session management)
  final String? sessionId;

  /// The history of the conversation.
  final List<ChatMessage> messages;

  /// The current connection status.
  final ConnectionStatus status;

  /// An optional error message when status is [ConnectionStatus.error].
  final String? errorMessage;

  /// Map of tasks tracked by their task ID
  /// Each task maintains its own lifecycle state, status messages, and artifacts
  final Map<String, TaskInfo> tasks;

  /// The current context ID for the active conversation
  final String? currentContextId;

  /// Gets the currently active task (most recent non-terminal task)
  TaskInfo? get activeTask {
    if (tasks.isEmpty) return null;

    // Find the most recent active task
    final activeTasks = tasks.values.where((task) => task.isActive).toList();
    if (activeTasks.isEmpty) return null;

    // Return the most recently updated active task
    activeTasks.sort((a, b) {
      if (a.lastUpdated == null) return 1;
      if (b.lastUpdated == null) return -1;
      return b.lastUpdated!.compareTo(a.lastUpdated!);
    });

    return activeTasks.first;
  }

  /// Gets all tasks for the current context sorted by last update time
  List<TaskInfo> get currentContextTasks {
    if (currentContextId == null) return [];

    final contextTasks = tasks.values
        .where((task) => task.contextId == currentContextId)
        .toList();

    contextTasks.sort((a, b) {
      if (a.lastUpdated == null) return 1;
      if (b.lastUpdated == null) return -1;
      return a.lastUpdated!.compareTo(b.lastUpdated!);
    });

    return contextTasks;
  }

  /// Creates a copy of this state with the given fields replaced.
  AgentState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    ConnectionStatus? status,
    String? errorMessage,
    Map<String, TaskInfo>? tasks,
    String? currentContextId,
  }) {
    return AgentState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      tasks: tasks ?? this.tasks,
      currentContextId: currentContextId ?? this.currentContextId,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        messages,
        status,
        errorMessage,
        tasks,
        currentContextId,
      ];
}
