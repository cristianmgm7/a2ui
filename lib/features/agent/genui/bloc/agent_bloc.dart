import 'dart:async';

import 'package:a2a/a2a.dart' as a2a;
import 'package:a2ui/features/agent/data/config/adk_config.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_event.dart';
import 'package:a2ui/features/agent/genui/bloc/agent_state.dart';
import 'package:a2ui/features/agent/genui/models/thinking_step.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

/// BLoC for managing the agent's state and interactions using A2A protocol.
///
/// This uses the A2AClient from the pure a2a package for simple text-based chat,
/// avoiding the complexity of A2UI surfaces and protocol parsing.
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
    } on Exception catch (e, stackTrace) {
      emit(state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

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
      isThinking: true, // NEW: Start thinking state
      currentThinkingSteps: [], // NEW: Reset thinking steps
      thinkingError: null, // NEW: Clear previous errors
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
      // hit the /message endpoint
      // Stream response from A2A server
      final streamingText = StringBuffer();

      final stream = _a2aClient!.sendMessageStream(params);

      await for (final response in stream) {
        // Handle error responses
        if (response.isError) {
          if (response is a2a.A2AJSONRPCErrorResponseSSM) {
            // Set thinking error
            emit(state.copyWith(
              thinkingError: 'Error: ${response.error?.toString() ?? "Unknown error"}',
              isThinking: false,
            ));
          }
          continue;
        }

        // Handle success responses
        if (response is a2a.A2ASendStreamMessageSuccessResponse) {
          final result = response.result;

          if (result != null) {
            if (result is a2a.A2ATaskStatusUpdateEvent) {
              _handleTaskStatusUpdate(result, streamingText, state.messages, emit);
            } else if (result is a2a.A2ATask) {
              _handleTask(result, streamingText, emit);
            } else if (result is a2a.A2AMessage) {
              _handleMessage(result, streamingText, emit);
            }
          }
        }
      }

      // Add final AI response to messages
      if (streamingText.isNotEmpty) {
        // Replace the last streaming message with the final complete message
        final currentMessages = state.messages;

        final finalMessages = _updateOrAddStreamingMessage(
          currentMessages,
          streamingText.toString(),
        );

        emit(state.copyWith(
          messages: finalMessages,
          status: ConnectionStatus.initial,
          isThinking: false, // End thinking state
        ));
      } else {
        emit(state.copyWith(
          status: ConnectionStatus.initial,
          isThinking: false, // End thinking state
        ));
      }
    } on Exception catch (e, stackTrace) {
      emit(state.copyWith(
        status: ConnectionStatus.error,
        errorMessage: 'Failed to send message: $e',
        isThinking: false, // NEW: End thinking state on error
        thinkingError: e.toString(), // NEW: Capture error
      ));
    }
  }

  void _handleTaskStatusUpdate(
    a2a.A2ATaskStatusUpdateEvent event,
    StringBuffer streamingText,
    List<ChatMessage> currentMessages,
    Emitter<AgentState> emit,
  ) {
    if (event.status != null) {
      final taskState = event.status!.state;

      // Handle thinking steps for working state
      if (taskState == a2a.A2ATaskState.working) {
        if (event.status!.message != null) {
          final message = event.status!.message;

          // Extract thinking message text
          final thinkingText = _extractThinkingText(message!.parts ?? []);

          // Heuristic: If text is very long (>200 chars), it's likely the final answer, not a thinking step
          final isLikelyFinalAnswer = thinkingText.length > 200;

          if (thinkingText.isNotEmpty && !isLikelyFinalAnswer) {
            // Add thinking step to state
            final newStep = ThinkingStep(
              message: thinkingText,
              timestamp: DateTime.now(),
            );

            final updatedSteps = [...state.currentThinkingSteps, newStep];

            emit(state.copyWith(
              currentThinkingSteps: updatedSteps,
              isThinking: true,
            ));
            // Skip text extraction for thinking steps
            return;
          } else if (isLikelyFinalAnswer) {
            // Don't return - let it fall through to extract as final response
          } else {
            return;
          }
        } else {
          return;
        }
      }

      // Continue with existing text extraction for final response
      _extractTextFromStatus(event.status!, streamingText, currentMessages, emit);
    }
  }

  void _handleTask(
    a2a.A2ATask task,
    StringBuffer streamingText,
    Emitter<AgentState> emit,
  ) {
    if (task.status != null) {
      _extractTextFromStatus(task.status!, streamingText, state.messages, emit);
    }
  }

  void _handleMessage(
    a2a.A2AMessage message,
    StringBuffer streamingText,
    Emitter<AgentState> emit,
  ) {
    _extractTextFromParts(message.parts ?? [], streamingText, state.messages, emit);
  }

  void _extractTextFromStatus(
    a2a.A2ATaskStatus status,
    StringBuffer streamingText,
    List<ChatMessage> currentMessages,
    Emitter<AgentState> emit,
  ) {
    if (status.message != null) {
      _extractTextFromParts(
        status.message!.parts ?? [],
        streamingText,
        currentMessages,
        emit,
        isWorking: status.state == a2a.A2ATaskState.working,
      );
    }
  }

  void _extractTextFromParts(
    List<a2a.A2APart> parts,
    StringBuffer streamingText,
    List<ChatMessage> currentMessages,
    Emitter<AgentState> emit, {
    bool isWorking = false,
  }) {
    for (final part in parts) {
      if (part is a2a.A2ATextPart) {
        final text = part.text;

        // Only accumulate text if not a thinking step
        // Thinking steps are handled separately in _handleTaskStatusUpdate
        if (!isWorking) {
          streamingText.write(text);

          // Emit intermediate updates for streaming display
          // Replace the last message if it's already an AI message (streaming), otherwise add new one
          final messagesWithStreaming = _updateOrAddStreamingMessage(
            currentMessages,
            streamingText.toString(),
          );

          emit(state.copyWith(
            messages: messagesWithStreaming,
            status: ConnectionStatus.streaming,
          ));
        }
      }
    }
  }

  /// Extracts text content from parts for thinking steps.
  ///
  /// This is separate from _extractTextFromParts because thinking steps
  /// should only extract text, not emit full state updates.
  String _extractThinkingText(List<a2a.A2APart> parts) {
    final buffer = StringBuffer();

    for (final part in parts) {
      if (part is a2a.A2ATextPart) {
        buffer.write(part.text);
      }
    }

    return buffer.toString().trim();
  }

  /// Updates the streaming AI message or adds a new one if none exists.
  ///
  /// This prevents multiple streaming messages from accumulating in the chat.
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
