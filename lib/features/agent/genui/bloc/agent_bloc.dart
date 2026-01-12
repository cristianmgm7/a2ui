import 'dart:async';

import 'package:a2a/a2a.dart' as a2a;
import 'package:a2ui/features/agent/data/config/adk_config.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_event.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_state.dart';
import 'package:a2ui/features/agent/genui/models/task_info.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

/// BLoC for managing the agent's state and interactions using A2A protocol.
///
/// This uses the A2AClient from the pure a2a package and properly tracks
/// individual tasks through their lifecycle with artifacts support.
class AgentBloc extends Bloc<AgentEvent, AgentState> {
  /// Creates an [AgentBloc].
  AgentBloc({
    Uri? serverUrl,
    String? sessionId,
  })  : _serverUrl = serverUrl ?? Uri.parse(AdkConfig.baseUrl),
        super(AgentState(sessionId: sessionId)) {
    on<InitializeAgent>(_onInitializeAgent);
    on<SendMessage>(_onSendMessage);
  }

  final Uri _serverUrl;

  a2a.A2AClient? _a2aClient;

  Future<void> _onInitializeAgent(
    InitializeAgent event,
    Emitter<AgentState> emit,
  ) async {
    emit(state.copyWith(status: ConnectionStatus.loading));
    try {
      // Create A2A client using pure a2a package
      // The client will fetch the agent card from /.well-known/agent.json
      _a2aClient = a2a.A2AClient(_serverUrl.toString());
      emit(state.copyWith(
        status: ConnectionStatus.initial,
        sessionId: event.sessionId ?? state.sessionId,
      ));
    } on Exception catch (e) {
      emit(state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Handles user message send event.
  ///
  /// A2A Protocol Flow:
  /// 1. User sends message (conversation)
  /// 2. Agent may respond with:
  ///    a) A2ATask - Initial task object with metadata
  ///    b) A2ATaskStatusUpdateEvent - Task progress/thinking steps (NOT conversation)
  ///    c) A2ATaskArtifactUpdateEvent - Generated files/data (NOT conversation)
  ///    d) A2AMessage - Actual agent response (ONLY THIS is conversation)
  ///
  /// Separation of concerns:
  /// - Tasks = Agent's internal work process
  /// - Artifacts = Tangible outputs (files, data)
  /// - Messages = Conversation between user and agent
  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<AgentState> emit,
  ) async {
    if (event.text.trim().isEmpty) return;

    // Add user message to conversation
    final userMessage = UserMessage.text(event.text);
    final updatedMessages = [...state.messages, userMessage];

    emit(state.copyWith(
      messages: updatedMessages,
      status: ConnectionStatus.streaming,
    ));

    try {
      if (_a2aClient == null) {
        throw Exception('A2A client not initialized. Call InitializeAgent first.');
      }

      // Create A2A message using pure a2a package
      final message = a2a.A2AMessage()
        ..messageId = DateTime.now().millisecondsSinceEpoch.toString()
        ..role = 'user'
        ..parts = [
          a2a.A2ATextPart()..text = event.text,
        ];

      // Create message send parameters
      final params = a2a.A2AMessageSendParams()..message = message;

      // Stream response from A2A server
      // NOTE: streamingText only accumulates A2AMessage content (conversation)
      // Task status updates are stored in TaskInfo, not here
      final streamingText = StringBuffer();
      final stream = _a2aClient!.sendMessageStream(params);

      await for (final response in stream) {
        // Handle error responses
        if (response.isError) {
          if (response is a2a.A2AJSONRPCErrorResponseSSM) {
            final errorMsg = 'Error: ${response.error?.toString() ?? "Unknown error"}';

            emit(state.copyWith(
              status: ConnectionStatus.error,
              errorMessage: errorMsg,
            ));
          }
          continue;
        }

        // Handle success responses
        if (response is a2a.A2ASendStreamMessageSuccessResponse) {
          final result = response.result;

          if (result != null) {
            if (result is a2a.A2ATask) {
              _handleTask(result, emit);
            } else if (result is a2a.A2ATaskStatusUpdateEvent) {
              _handleTaskStatusUpdate(result, streamingText, emit);
            } else if (result is a2a.A2ATaskArtifactUpdateEvent) {
              _handleArtifactUpdate(result, emit);
            } else if (result is a2a.A2AMessage) {
              _handleMessage(result, streamingText, emit);
            }
          }
        }
      }

      // Add final AI response to messages if we accumulated text from A2AMessage
      // NOTE: It's valid for tasks to complete without an A2AMessage
      // (e.g., agent just generates artifacts without explanatory text)
      if (streamingText.isNotEmpty) {
        final currentMessages = state.messages;
        final finalMessages = _updateOrAddStreamingMessage(
          currentMessages,
          streamingText.toString(),
        );

        emit(state.copyWith(
          messages: finalMessages,
          status: ConnectionStatus.initial,
        ));
      } else {
        // No conversation message - tasks may have completed with just artifacts
        emit(state.copyWith(
          status: ConnectionStatus.initial,
        ));
      }
    } on Exception catch (e) {
      emit(state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Failed to send message: $e',
      ));
    }
  }

  /// Handles initial Task object from the stream.
  void _handleTask(
    a2a.A2ATask task,
    Emitter<AgentState> emit,
  ) {
    final taskId = task.id;
    final contextId = task.contextId;

    // Create or update task in our state
    final updatedTasks = Map<String, TaskInfo>.from(state.tasks);

    final taskInfo = TaskInfo(
      taskId: taskId,
      contextId: contextId,
      state: mapA2ATaskState(task.status?.state),
      statusMessages: [],
      artifacts: task.artifacts ?? [],
      lastUpdated: DateTime.now(),
    );

    updatedTasks[taskId] = taskInfo;

    emit(state.copyWith(
      tasks: updatedTasks,
      currentContextId: contextId,
    ));
  }

  /// Handles TaskStatusUpdateEvent for task lifecycle changes.
  ///
  /// IMPORTANT: Task status messages are NOT conversation messages.
  /// They represent the agent's thinking/working process and should
  /// only be stored in the TaskInfo, never in the messages list.
  void _handleTaskStatusUpdate(
    a2a.A2ATaskStatusUpdateEvent event,
    StringBuffer streamingText,
    Emitter<AgentState> emit,
  ) {
    final taskId = event.taskId;
    final contextId = event.contextId;

    // Get existing task or create new one
    final updatedTasks = Map<String, TaskInfo>.from(state.tasks);
    var taskInfo = updatedTasks[taskId] ??
        TaskInfo(
          taskId: taskId,
          contextId: contextId,
          lastUpdated: DateTime.now(),
        );

    // Update task state
    final newState = mapA2ATaskState(event.status?.state);

    // Extract status message if present
    // ALL status messages go to the task, regardless of state
    List<TaskMessagePart> updatedStatusMessages = List.from(taskInfo.statusMessages);

    if (event.status?.message != null) {
      final messageText = _extractTextFromParts(event.status!.message!.parts ?? []);

      if (messageText.isNotEmpty) {
        // Add status message to task (thinking step)
        // These are NOT conversation messages - they're task progress updates
        updatedStatusMessages.add(TaskMessagePart(
          text: messageText,
          timestamp: DateTime.now(),
        ));
      }
    }

    // Update task info
    taskInfo = taskInfo.copyWith(
      state: newState,
      statusMessages: updatedStatusMessages,
      isFinal: event.end ?? false,
      lastUpdated: DateTime.now(),
    );

    updatedTasks[taskId] = taskInfo;

    emit(state.copyWith(
      tasks: updatedTasks,
      currentContextId: contextId,
    ));
  }

  /// Handles TaskArtifactUpdateEvent for artifact generation.
  void _handleArtifactUpdate(
    a2a.A2ATaskArtifactUpdateEvent event,
    Emitter<AgentState> emit,
  ) {
    final taskId = event.taskId;
    final contextId = event.contextId;

    if (event.artifact == null) return;

    // Get existing task or create new one
    final updatedTasks = Map<String, TaskInfo>.from(state.tasks);
    var taskInfo = updatedTasks[taskId] ??
        TaskInfo(
          taskId: taskId,
          contextId: contextId,
          lastUpdated: DateTime.now(),
        );

    // Update artifacts list
    final updatedArtifacts = List<a2a.A2AArtifact>.from(taskInfo.artifacts);

    final artifact = event.artifact!;
    final existingIndex = updatedArtifacts.indexWhere(
      (a) => a.artifactId == artifact.artifactId,
    );

    if (event.append == true && existingIndex != -1) {
      // Append to existing artifact
      final existing = updatedArtifacts[existingIndex];
      final mergedParts = [...existing.parts, ...artifact.parts];

      updatedArtifacts[existingIndex] = a2a.A2AArtifact()
        ..artifactId = artifact.artifactId
        ..name = artifact.name ?? existing.name
        ..description = artifact.description ?? existing.description
        ..parts = mergedParts
        ..metadata = artifact.metadata ?? existing.metadata
        ..extensions = artifact.extensions ?? existing.extensions;
    } else if (existingIndex != -1) {
      // Replace existing artifact
      updatedArtifacts[existingIndex] = artifact;
    } else {
      // Add new artifact
      updatedArtifacts.add(artifact);
    }

    // Update task info
    taskInfo = taskInfo.copyWith(
      artifacts: updatedArtifacts,
      lastUpdated: DateTime.now(),
    );

    updatedTasks[taskId] = taskInfo;

    emit(state.copyWith(
      tasks: updatedTasks,
      currentContextId: contextId,
    ));
  }

  /// Handles direct Message responses from the agent.
  ///
  /// IMPORTANT: This is the ONLY place where agent text becomes a conversation message.
  /// A2AMessage represents actual agent responses in the conversation, NOT task status.
  ///
  /// Flow:
  /// - User sends message
  /// - Agent creates tasks (optional)
  /// - Tasks have status updates (thinking steps) - NOT conversation messages
  /// - Tasks may produce artifacts (files/data) - NOT conversation messages
  /// - Agent sends A2AMessage - THIS becomes a conversation message
  void _handleMessage(
    a2a.A2AMessage message,
    StringBuffer streamingText,
    Emitter<AgentState> emit,
  ) {
    final text = _extractTextFromParts(message.parts ?? []);

    if (text.isNotEmpty) {
      streamingText.write(text);

      // Emit intermediate updates for streaming display
      final messagesWithStreaming = _updateOrAddStreamingMessage(
        state.messages,
        streamingText.toString(),
      );

      emit(state.copyWith(
        messages: messagesWithStreaming,
        status: ConnectionStatus.streaming,
      ));
    }
  }

  /// Extracts text content from A2A parts.
  String _extractTextFromParts(List<a2a.A2APart> parts) {
    final buffer = StringBuffer();

    for (final part in parts) {
      if (part is a2a.A2ATextPart) {
        buffer.write(part.text);
      }
    }

    return buffer.toString().trim();
  }

  /// Updates the streaming AI message or adds a new one if none exists.
  List<ChatMessage> _updateOrAddStreamingMessage(
    List<ChatMessage> currentMessages,
    String streamingText,
  ) {
    // Check if the last message is already a streaming AI message
    if (currentMessages.isNotEmpty && currentMessages.last is AiTextMessage) {
      // Replace the last message with updated streaming text
      final updatedMessages = List<ChatMessage>.from(currentMessages);
      updatedMessages[updatedMessages.length - 1] = AiTextMessage([TextPart(streamingText)]);
      return updatedMessages;
    } else {
      // Add new streaming message
      return [...currentMessages, AiTextMessage([TextPart(streamingText)])];
    }
  }

  @override
  Future<void> close() async {
    // A2AClient doesn't have a close method, it's stateless
    _a2aClient = null;
    return super.close();
  }
}
