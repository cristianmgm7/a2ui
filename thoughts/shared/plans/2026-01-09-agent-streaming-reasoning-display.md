# Agent Streaming Reasoning & Status Display Implementation Plan

## Overview

Implement real-time visibility into agent processing by capturing and displaying intermediate A2A protocol events (reasoning, tool usage, status updates) and streaming text responses incrementally as they arrive. This will provide ChatGPT/Claude-style transparency into what the agent is thinking and doing behind the scenes.

## Current State Analysis

### What Exists Now

**A2A Streaming Infrastructure:**
- SSE transport layer already established via `SseTransport` (a2ui_agent_connector.dart:36-40)
- Three A2A event types available:
  - `StatusUpdate` - Task status changes with optional message
  - `TaskStatusUpdate` - Detailed task progress updates with message
  - `ArtifactUpdate` - Streaming artifacts with `append` and `lastChunk` flags
- Raw events logged but not surfaced to UI (a2ui_agent_connector.dart:152-219)

**Current State Management:**
- `AgentState` tracks: messages, surfaces, surfaceIds, currentSurfaceId, status, errorMessage
- `ConnectionStatus` enum: initial, loading, streaming, error
- Messages updated via full list replacement (agent_bloc.dart:167-170)
- Status changes to `streaming` when sending messages, returns to `initial` when complete

**Current UI:**
- `MessageBubble` displays user/agent messages (message_bubble.dart)
- `ChatPanel` shows message list with reverse scroll (chat_panel.dart)
- Small CircularProgressIndicator in app bar during streaming (chat_app_bar.dart:31-39)
- No visibility into what is being processed during streaming state

### Key Constraints Discovered

1. **Full Message Replacement**: Current architecture replaces entire message list, no incremental updates
2. **Event Processing**: Only `DataPart` with A2UI messages (surfaceUpdate, dataModelUpdate) are processed (a2ui_agent_connector.dart:277-296)
3. **No Intermediate State**: StatusUpdate events with `state=working` are logged but not captured in state
4. **Message Types**: Only `UserMessage` and `AiTextMessage` supported in MessageBubble

## Desired End State

### Functional Requirements

1. **Expandable Reasoning Display**:
   - Agent message bubbles have an expandable "Details" section
   - Details show chronological list of thinking steps and actions taken
   - Collapsed by default, user can expand to see reasoning process

2. **Real-Time Text Streaming**:
   - Agent responses appear word-by-word/chunk-by-chunk as received
   - Text streams via `ArtifactUpdate` events with `append: true`
   - Smooth typing animation effect

3. **Medium-Detail Status Updates**:
   - Show major processing steps: "Analyzing request...", "Searching database...", "Calling API..."
   - Display tool usage and significant state changes
   - Filter out minor internal operations

4. **Server Event Investigation**:
   - Add detailed logging to understand what events server actually emits
   - Identify patterns for extracting reasoning/status information
   - Create fallback for servers that don't emit intermediate events

### Verification Criteria

#### Automated Verification:
- [ ] Code compiles without errors: `flutter analyze`
- [ ] All existing tests pass: `flutter test`
- [ ] No new linter warnings introduced
- [ ] State management follows existing BLoC pattern
- [ ] Widget tree properly rebuilds on state changes

#### Manual Verification:
- [ ] Agent message bubbles display "Show Details" / "Hide Details" toggle
- [ ] Expanding details shows chronological list of reasoning steps
- [ ] Agent text responses stream incrementally (if server supports)
- [ ] Status updates appear in details section with timestamps
- [ ] Tool usage displayed with meaningful descriptions
- [ ] Streaming state visible in app bar indicator
- [ ] Performance acceptable with long reasoning chains
- [ ] No UI flickering during rapid updates
- [ ] Details remain accessible after streaming completes

## What We're NOT Doing

- Not modifying the A2A protocol or connector's core streaming logic
- Not adding text-to-speech or audio features
- Not implementing user-configurable detail level filters (fixed to medium detail)
- Not showing streaming indicators within individual message text
- Not persisting expanded/collapsed state across app restarts
- Not adding search or filtering within reasoning details
- Not implementing custom server-side event generation
- Not creating a separate status panel (keeping it in message bubbles)

## Implementation Approach

### High-Level Strategy

1. **Phase 1**: Add event inspection logging to understand server behavior
2. **Phase 2**: Extend state management to capture intermediate events
3. **Phase 3**: Implement streaming message data structures
4. **Phase 4**: Build expandable details UI component
5. **Phase 5**: Connect streaming text display
6. **Phase 6**: Polish and optimize performance

### Technical Decisions

**State Architecture:**
- Add `streamingMessages` map to AgentState: `Map<String, StreamingMessage>`
- Each StreamingMessage tracks: text chunks, reasoning steps, status, isComplete
- Keep existing `messages` list for completed messages
- Transition streaming message to final message when complete

**Event Processing:**
- Modify `connectAndSend` in A2uiAgentConnector to expose raw event stream
- Create new `OnRawEventReceived` event in AgentBloc
- Process events in bloc to extract reasoning/status information
- Use TaskStatus.message.parts to extract thinking text

**UI Components:**
- Create `StreamingMessageBubble` widget for in-progress messages
- Create `ReasoningDetails` expandable widget
- Create `ReasoningStep` widget for individual status entries
- Modify ChatPanel to render both completed and streaming messages

---

## Phase 1: Event Inspection & Logging

### Overview
Add comprehensive logging to capture and understand what A2A events the server emits during processing. This will inform how we extract reasoning and status information.

### Changes Required

#### 1. Enhanced A2uiAgentConnector Logging
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Add detailed event logging in initialization

```dart
Future<void> _onInitializeAgent(
  InitializeAgent event,
  Emitter<AgentState> emit,
) async {
  emit(state.copyWith(status: ConnectionStatus.loading));

  try {
    // ... existing initialization code ...

    // Add logging configuration
    genUiLogger.level = Level.FINE; // Ensure detailed logs are visible
    genUiLogger.info('Agent initialization complete. Ready to capture streaming events.');

    emit(state.copyWith(
      status: ConnectionStatus.initial,
      surfaceIds: existingSurfaceIds,
      surfaces: Map.from(_a2uiMessageProcessor!.surfaces),
    ));
  } catch (e) {
    genUiLogger.severe('Agent initialization failed: $e');
    emit(state.copyWith(
      status: ConnectionStatus.error,
      errorMessage: e.toString(),
    ));
  }
}
```

#### 2. Create Event Capture Test
**File**: `test/agent/event_capture_test.dart` (new file)
**Changes**: Create test to capture and log events

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:genui_a2ui/genui_a2ui.dart';
import 'package:logging/logging.dart';

void main() {
  group('A2A Event Capture', () {
    late A2uiAgentConnector connector;

    setUp(() {
      // Configure verbose logging
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        print('[${record.level.name}] ${record.time}: ${record.message}');
      });

      // Replace with your test server URL
      connector = A2uiAgentConnector(
        url: Uri.parse('http://localhost:10003'),
      );
    });

    test('Capture all events during message processing', () async {
      final allEvents = <Event>[];

      final message = UserMessage.text('Hello, can you help me?');

      // This test will help us see what events the server sends
      await connector.connectAndSend(message);

      // Events are logged automatically
      // Check console output for event structure
    });
  });
}
```

#### 3. Add Event Type Counter
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Add diagnostic event counting

```dart
class AgentBloc extends Bloc<AgentEvent, AgentState> {
  // ... existing fields ...

  // Diagnostic counters
  final Map<String, int> _eventCounts = {};

  // ... existing methods ...

  void _logEventStatistics() {
    genUiLogger.info('=== Event Statistics ===');
    _eventCounts.forEach((type, count) {
      genUiLogger.info('$type: $count events');
    });
    genUiLogger.info('=======================');
  }

  @override
  Future<void> close() {
    _logEventStatistics();
    // ... existing cleanup ...
    return super.close();
  }
}
```

### Success Criteria

#### Automated Verification:
- [ ] Event capture test compiles: `flutter test test/agent/event_capture_test.dart`
- [ ] No compilation errors: `flutter analyze`
- [ ] Logging statements execute without errors

#### Manual Verification:
- [ ] Run app and send a test message to the agent
- [ ] Console shows detailed A2A event logs with timestamps
- [ ] Can identify at least these event types in logs:
  - StatusUpdate or TaskStatusUpdate events
  - Event states (submitted, working, completed)
  - Message parts (TextPart, DataPart) within events
- [ ] Logs show whether server emits intermediate "working" state events
- [ ] Event statistics printed on app close show event type distribution
- [ ] Captured logs reveal structure of reasoning/status information (if present)

**Implementation Note**: After completing this phase and confirming event structure through logs, proceed to Phase 2. If server doesn't emit intermediate events, plan will adapt to show generic "processing" status.

---

## Phase 2: State Management for Streaming

### Overview
Extend AgentState and AgentBloc to track intermediate streaming events, reasoning steps, and incremental text updates.

### Changes Required

#### 1. Create Streaming Message Models
**File**: `lib/features/agent/models/streaming_message.dart` (new file)
**Changes**: Define data structures for streaming messages

```dart
import 'package:equatable/equatable.dart';

/// Represents a single reasoning or status step during agent processing.
class ReasoningStep extends Equatable {
  const ReasoningStep({
    required this.timestamp,
    required this.description,
    this.type = ReasoningStepType.status,
  });

  final DateTime timestamp;
  final String description;
  final ReasoningStepType type;

  @override
  List<Object?> get props => [timestamp, description, type];
}

/// Types of reasoning steps for categorization.
enum ReasoningStepType {
  status,      // General status update
  thinking,    // Agent reasoning/planning
  toolUse,     // Tool or API usage
  error,       // Error or warning
}

/// Represents an in-progress agent message with streaming text and reasoning.
class StreamingMessage extends Equatable {
  const StreamingMessage({
    required this.messageId,
    this.textChunks = const [],
    this.reasoningSteps = const [],
    this.isComplete = false,
    this.timestamp,
  });

  final String messageId;
  final List<String> textChunks;
  final List<ReasoningStep> reasoningSteps;
  final bool isComplete;
  final DateTime? timestamp;

  /// Get the full text by joining all chunks.
  String get fullText => textChunks.join('');

  StreamingMessage copyWith({
    List<String>? textChunks,
    List<ReasoningStep>? reasoningSteps,
    bool? isComplete,
  }) {
    return StreamingMessage(
      messageId: messageId,
      textChunks: textChunks ?? this.textChunks,
      reasoningSteps: reasoningSteps ?? this.reasoningSteps,
      isComplete: isComplete ?? this.isComplete,
      timestamp: timestamp,
    );
  }

  @override
  List<Object?> get props => [messageId, textChunks, reasoningSteps, isComplete, timestamp];
}
```

#### 2. Extend AgentState
**File**: `lib/features/agent/bloc/agent_state.dart`
**Changes**: Add streaming message tracking

```dart
class AgentState extends Equatable {
  const AgentState({
    this.messages = const [],
    this.surfaces = const {},
    this.surfaceIds = const ['default'],
    this.currentSurfaceId = 'default',
    this.status = ConnectionStatus.initial,
    this.errorMessage,
    this.streamingMessages = const {}, // NEW
    this.currentStreamingMessageId,    // NEW
  });

  // ... existing fields ...

  /// Map of message IDs to streaming messages currently being processed.
  final Map<String, StreamingMessage> streamingMessages;

  /// ID of the currently active streaming message, if any.
  final String? currentStreamingMessageId;

  AgentState copyWith({
    List<ChatMessage>? messages,
    Map<String, dynamic>? surfaces,
    List<String>? surfaceIds,
    String? currentSurfaceId,
    ConnectionStatus? status,
    String? errorMessage,
    Map<String, StreamingMessage>? streamingMessages, // NEW
    String? currentStreamingMessageId,                 // NEW
  }) {
    return AgentState(
      messages: messages ?? this.messages,
      surfaces: surfaces ?? this.surfaces,
      surfaceIds: surfaceIds ?? this.surfaceIds,
      currentSurfaceId: currentSurfaceId ?? this.currentSurfaceId,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      streamingMessages: streamingMessages ?? this.streamingMessages,
      currentStreamingMessageId: currentStreamingMessageId ?? this.currentStreamingMessageId,
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
        streamingMessages,       // NEW
        currentStreamingMessageId, // NEW
      ];
}
```

#### 3. Add Streaming Events
**File**: `lib/features/agent/bloc/agent_event.dart`
**Changes**: Add events for streaming updates

```dart
/// Event triggered when a raw A2A event is received (for intermediate processing).
class OnRawEventReceived extends AgentEvent {
  const OnRawEventReceived(this.event);

  final Event event;

  @override
  List<Object?> get props => [event];
}

/// Event to add a text chunk to the current streaming message.
class OnTextChunkReceived extends AgentEvent {
  const OnTextChunkReceived(this.messageId, this.textChunk);

  final String messageId;
  final String textChunk;

  @override
  List<Object?> get props => [messageId, textChunk];
}

/// Event to add a reasoning step to the current streaming message.
class OnReasoningStepAdded extends AgentEvent {
  const OnReasoningStepAdded(this.messageId, this.step);

  final String messageId;
  final ReasoningStep step;

  @override
  List<Object?> get props => [messageId, step];
}

/// Event to mark a streaming message as complete.
class OnStreamingMessageComplete extends AgentEvent {
  const OnStreamingMessageComplete(this.messageId);

  final String messageId;

  @override
  List<Object?> get props => [messageId];
}
```

#### 4. Modify AgentBloc to Expose Raw Events
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Register new event handlers and capture raw events

```dart
class AgentBloc extends Bloc<AgentEvent, AgentState> {
  AgentBloc({
    Uri? serverUrl,
  })  : _serverUrl = serverUrl ?? Uri.parse('http://localhost:10003'),
        super(const AgentState()) {
    on<InitializeAgent>(_onInitializeAgent);
    on<SendMessage>(_onSendMessage);
    on<OnProtocolUpdate>(_onProtocolUpdate);
    on<OnMessagesUpdated>(_onMessagesUpdated);
    on<SwitchSurface>(_onSwitchSurface);
    on<NextSurface>(_onNextSurface);
    on<PreviousSurface>(_onPreviousSurface);
    // NEW event handlers
    on<OnRawEventReceived>(_onRawEventReceived);
    on<OnTextChunkReceived>(_onTextChunkReceived);
    on<OnReasoningStepAdded>(_onReasoningStepAdded);
    on<OnStreamingMessageComplete>(_onStreamingMessageComplete);
  }

  // ... existing fields and methods ...

  Future<void> _onRawEventReceived(
    OnRawEventReceived event,
    Emitter<AgentState> emit,
  ) async {
    final rawEvent = event.event;

    if (rawEvent is StatusUpdate || rawEvent is TaskStatusUpdate) {
      final taskId = rawEvent is StatusUpdate
          ? rawEvent.taskId
          : (rawEvent as TaskStatusUpdate).taskId;
      final status = rawEvent is StatusUpdate
          ? rawEvent.status
          : (rawEvent as TaskStatusUpdate).status;

      // Extract reasoning from message parts
      if (status.message != null) {
        for (final part in status.message!.parts) {
          if (part is TextPart) {
            // Check if this looks like reasoning text
            final text = part.text.trim();
            if (text.isNotEmpty && _isReasoningText(text)) {
              add(OnReasoningStepAdded(
                taskId,
                ReasoningStep(
                  timestamp: DateTime.now(),
                  description: text,
                  type: _determineStepType(text, status.state),
                ),
              ));
            }
          }
        }
      }
    } else if (rawEvent is ArtifactUpdate) {
      // Handle streaming text via artifacts
      if (rawEvent.append) {
        for (final part in rawEvent.artifact.parts) {
          if (part is TextPart) {
            add(OnTextChunkReceived(rawEvent.taskId, part.text));
          }
        }
      }

      if (rawEvent.lastChunk) {
        add(OnStreamingMessageComplete(rawEvent.taskId));
      }
    }
  }

  bool _isReasoningText(String text) {
    // Filter for reasoning-like text
    final lowerText = text.toLowerCase();
    return lowerText.contains('thinking') ||
           lowerText.contains('analyzing') ||
           lowerText.contains('searching') ||
           lowerText.contains('calling') ||
           lowerText.contains('processing') ||
           lowerText.startsWith('step') ||
           text.length > 10; // Basic heuristic
  }

  ReasoningStepType _determineStepType(String text, TaskState state) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('error') || lowerText.contains('failed') || state == TaskState.failed) {
      return ReasoningStepType.error;
    } else if (lowerText.contains('thinking') || lowerText.contains('reasoning')) {
      return ReasoningStepType.thinking;
    } else if (lowerText.contains('calling') || lowerText.contains('using') || lowerText.contains('tool')) {
      return ReasoningStepType.toolUse;
    }

    return ReasoningStepType.status;
  }

  Future<void> _onTextChunkReceived(
    OnTextChunkReceived event,
    Emitter<AgentState> emit,
  ) async {
    final messageId = event.messageId;
    final chunk = event.textChunk;

    final currentStreamingMessages = Map<String, StreamingMessage>.from(state.streamingMessages);

    final existingMessage = currentStreamingMessages[messageId] ?? StreamingMessage(
      messageId: messageId,
      timestamp: DateTime.now(),
    );

    currentStreamingMessages[messageId] = existingMessage.copyWith(
      textChunks: [...existingMessage.textChunks, chunk],
    );

    emit(state.copyWith(
      streamingMessages: currentStreamingMessages,
      currentStreamingMessageId: messageId,
    ));
  }

  Future<void> _onReasoningStepAdded(
    OnReasoningStepAdded event,
    Emitter<AgentState> emit,
  ) async {
    final messageId = event.messageId;
    final step = event.step;

    final currentStreamingMessages = Map<String, StreamingMessage>.from(state.streamingMessages);

    final existingMessage = currentStreamingMessages[messageId] ?? StreamingMessage(
      messageId: messageId,
      timestamp: DateTime.now(),
    );

    currentStreamingMessages[messageId] = existingMessage.copyWith(
      reasoningSteps: [...existingMessage.reasoningSteps, step],
    );

    emit(state.copyWith(
      streamingMessages: currentStreamingMessages,
      currentStreamingMessageId: messageId,
    ));
  }

  Future<void> _onStreamingMessageComplete(
    OnStreamingMessageComplete event,
    Emitter<AgentState> emit,
  ) async {
    final messageId = event.messageId;

    final currentStreamingMessages = Map<String, StreamingMessage>.from(state.streamingMessages);
    final streamingMessage = currentStreamingMessages[messageId];

    if (streamingMessage != null) {
      currentStreamingMessages[messageId] = streamingMessage.copyWith(isComplete: true);

      emit(state.copyWith(
        streamingMessages: currentStreamingMessages,
        status: ConnectionStatus.initial,
      ));
    }
  }
}
```

#### 5. Modify A2uiAgentConnector to Emit Raw Events
**File**: `lib/features/agent/data/raw_event_connector.dart` (new file)
**Changes**: Create wrapper to expose raw events

```dart
import 'dart:async';
import 'package:genui_a2ui/genui_a2ui.dart';

/// Wrapper around A2uiAgentConnector that exposes raw A2A events.
class RawEventConnector {
  RawEventConnector(this.connector);

  final A2uiAgentConnector connector;
  final _rawEventController = StreamController<Event>.broadcast();

  Stream<Event> get rawEventStream => _rawEventController.stream;

  /// Connect and send, but also emit raw events to the stream.
  Future<String?> connectAndSend(
    ChatMessage chatMessage, {
    A2UiClientCapabilities? clientCapabilities,
  }) async {
    // Access the client's message stream directly
    final message = _convertChatMessage(chatMessage);
    final Stream<Event> events = connector.client.messageStream(message);

    String? responseText;
    await for (final event in events) {
      // Emit to raw event stream for bloc processing
      if (!_rawEventController.isClosed) {
        _rawEventController.add(event);
      }

      // Continue normal processing
      // (This replicates connector.connectAndSend logic)
      if (event is StatusUpdate || event is TaskStatusUpdate) {
        final status = event is StatusUpdate
            ? event.status
            : (event as TaskStatusUpdate).status;

        if (status.message != null) {
          for (final part in status.message!.parts) {
            if (part is TextPart) {
              responseText = part.text;
            }
          }
        }
      }
    }

    return responseText;
  }

  Message _convertChatMessage(ChatMessage chatMessage) {
    // Implement conversion logic similar to A2uiAgentConnector
    // This is simplified; actual implementation should match connector's logic
    final parts = <Part>[];
    if (chatMessage is UserMessage) {
      parts.add(Part.text(text: chatMessage.text));
    }

    return Message(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      role: Role.user,
      parts: parts,
    );
  }

  void dispose() {
    _rawEventController.close();
  }
}
```

### Success Criteria

#### Automated Verification:
- [ ] Code compiles without errors: `flutter analyze`
- [ ] All model classes have proper Equatable implementation
- [ ] StreamingMessage model tests pass: `flutter test test/models/streaming_message_test.dart`
- [ ] State copyWith preserves all fields correctly
- [ ] No memory leaks in stream controllers (dispose called)

#### Manual Verification:
- [ ] Send test message and verify state updates in BLoC debugger
- [ ] `streamingMessages` map populates during message processing
- [ ] `currentStreamingMessageId` updates to active message ID
- [ ] Reasoning steps accumulate in chronological order
- [ ] Text chunks accumulate in order received
- [ ] Streaming message marked complete when final event arrives
- [ ] State transitions: initial → streaming → initial
- [ ] Multiple concurrent streaming messages handled correctly
- [ ] App doesn't crash with rapid state updates

**Implementation Note**: After state management is working, verify reasoning steps are being captured correctly before proceeding to UI phase. Use Flutter DevTools to inspect state.

---

## Phase 3: Raw Event Stream Integration

### Overview
Modify the agent bloc's send message flow to capture and process raw A2A events before they're converted to A2UI messages.

### Changes Required

#### 1. Refactor AgentBloc SendMessage Handler
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Intercept raw event stream in _onSendMessage

```dart
Future<void> _onSendMessage(
  SendMessage event,
  Emitter<AgentState> emit,
) async {
  if (event.text.trim().isEmpty) return;

  emit(state.copyWith(status: ConnectionStatus.streaming));

  // Create a new streaming message entry
  final messageId = DateTime.now().millisecondsSinceEpoch.toString();
  final streamingMessages = Map<String, StreamingMessage>.from(state.streamingMessages);
  streamingMessages[messageId] = StreamingMessage(
    messageId: messageId,
    timestamp: DateTime.now(),
  );

  emit(state.copyWith(
    streamingMessages: streamingMessages,
    currentStreamingMessageId: messageId,
  ));

  // Send the message and listen to raw events
  _sendMessageWithRawEvents(event.text, messageId);
}

void _sendMessageWithRawEvents(String text, String messageId) async {
  try {
    // Access the raw event stream from the connector's client
    final message = Message(
      messageId: messageId,
      role: Role.user,
      parts: [Part.text(text: text)],
    );

    final Stream<Event> events = _contentGenerator!.connector.client.messageStream(message);

    await for (final event in events) {
      // Emit raw event for processing
      add(OnRawEventReceived(event));

      // Let the existing protocol update handler deal with A2UI messages
      if (event is StatusUpdate || event is TaskStatusUpdate) {
        final status = event is StatusUpdate
            ? event.status
            : (event as TaskStatusUpdate).status;

        if (status.message != null) {
          for (final part in status.message!.parts) {
            if (part is DataPart) {
              _contentGenerator!.connector._processA2uiMessages(part.data);
            }
          }
        }
      }
    }

    // Mark streaming complete
    add(OnStreamingMessageComplete(messageId));
  } catch (e) {
    genUiLogger.severe('Error processing message stream: $e');
  }
}
```

#### 2. Update Initialization to Expose Client
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Ensure connector client is accessible

```dart
Future<void> _onInitializeAgent(
  InitializeAgent event,
  Emitter<AgentState> emit,
) async {
  emit(state.copyWith(status: ConnectionStatus.loading));

  try {
    // ... existing catalog creation ...

    _a2uiMessageProcessor = A2uiMessageProcessor(
      catalogs: [
        CoreCatalogItems.asCatalog(),
        customAuthCatalog,
      ],
    );

    _contentGenerator = A2uiContentGenerator(
      serverUrl: _serverUrl,
    );

    // NEW: Store reference to connector for raw event access
    _connector = _contentGenerator!.connector;

    _genUiConversation = GenUiConversation(
      contentGenerator: _contentGenerator!,
      a2uiMessageProcessor: _a2uiMessageProcessor!,
    );

    // ... rest of initialization ...
  } catch (e) {
    // ... error handling ...
  }
}

// Add field
A2uiAgentConnector? _connector;
```

### Success Criteria

#### Automated Verification:
- [ ] Code compiles without errors: `flutter analyze`
- [ ] No breaking changes to existing message flow
- [ ] Stream subscription properly cleaned up on dispose
- [ ] Error handling doesn't crash app

#### Manual Verification:
- [ ] Send message triggers raw event stream processing
- [ ] OnRawEventReceived events dispatched for each A2A event
- [ ] StreamingMessage created at start of processing
- [ ] Raw events processed before A2UI messages
- [ ] Existing surface updates still work correctly
- [ ] OnStreamingMessageComplete dispatched when stream ends
- [ ] Multiple messages in sequence handled correctly
- [ ] Console logs show raw events being received
- [ ] No duplicate event processing

**Implementation Note**: Test thoroughly with multiple consecutive messages. Ensure streaming state doesn't get stuck in "streaming" mode if errors occur.

---

## Phase 4: Expandable Details UI Component

### Overview
Create UI components to display streaming messages with expandable reasoning details in message bubbles.

### Changes Required

#### 1. Create ReasoningStep Widget
**File**: `lib/features/agent/presentation/widgets/reasoning_step_widget.dart` (new file)
**Changes**: Widget to display individual reasoning step

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/streaming_message.dart';

class ReasoningStepWidget extends StatelessWidget {
  const ReasoningStepWidget({
    super.key,
    required this.step,
  });

  final ReasoningStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm:ss.SSS');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon based on step type
          Icon(
            _getIconForType(step.type),
            size: 16,
            color: _getColorForType(step.type, theme),
          ),
          const SizedBox(width: 8),
          // Timestamp
          Text(
            timeFormat.format(step.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // Description
          Expanded(
            child: Text(
              step.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(ReasoningStepType type) {
    switch (type) {
      case ReasoningStepType.thinking:
        return Icons.psychology;
      case ReasoningStepType.toolUse:
        return Icons.build;
      case ReasoningStepType.error:
        return Icons.error_outline;
      case ReasoningStepType.status:
        return Icons.info_outline;
    }
  }

  Color _getColorForType(ReasoningStepType type, ThemeData theme) {
    switch (type) {
      case ReasoningStepType.thinking:
        return theme.colorScheme.primary;
      case ReasoningStepType.toolUse:
        return theme.colorScheme.secondary;
      case ReasoningStepType.error:
        return theme.colorScheme.error;
      case ReasoningStepType.status:
        return theme.colorScheme.onSurface.withOpacity(0.6);
    }
  }
}
```

#### 2. Create ReasoningDetails Expandable Widget
**File**: `lib/features/agent/presentation/widgets/reasoning_details.dart` (new file)
**Changes**: Expandable panel for reasoning steps

```dart
import 'package:flutter/material.dart';
import '../../models/streaming_message.dart';
import 'reasoning_step_widget.dart';

class ReasoningDetails extends StatefulWidget {
  const ReasoningDetails({
    super.key,
    required this.steps,
  });

  final List<ReasoningStep> steps;

  @override
  State<ReasoningDetails> createState() => _ReasoningDetailsState();
}

class _ReasoningDetailsState extends State<ReasoningDetails> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isExpanded ? 'Hide Details' : 'Show Details',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.steps.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: theme.colorScheme.outline.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  ...widget.steps.map((step) => ReasoningStepWidget(step: step)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

#### 3. Create StreamingMessageBubble Widget
**File**: `lib/features/agent/presentation/widgets/streaming_message_bubble.dart` (new file)
**Changes**: Message bubble that displays streaming content

```dart
import 'package:flutter/material.dart';
import '../../models/streaming_message.dart';
import 'reasoning_details.dart';

class StreamingMessageBubble extends StatelessWidget {
  const StreamingMessageBubble({
    super.key,
    required this.streamingMessage,
  });

  final StreamingMessage streamingMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = streamingMessage.fullText;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              child: streamingMessage.isComplete
                  ? const Text('A')
                  : SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Text(
                      'Agent',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (!streamingMessage.isComplete) ...[
                      const SizedBox(width: 8),
                      Text(
                        'typing...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: text.isNotEmpty
                      ? Text(text)
                      : Text(
                          'Thinking...',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                ),
                // Reasoning details
                ReasoningDetails(steps: streamingMessage.reasoningSteps),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 4. Update MessageBubble to Support Reasoning
**File**: `lib/features/agent/presentation/widgets/message_bubble.dart`
**Changes**: Add optional reasoning details to completed messages

```dart
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import '../../models/streaming_message.dart';
import 'reasoning_details.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.reasoningSteps, // NEW: optional reasoning steps
  });

  final ChatMessage message;
  final List<ReasoningStep>? reasoningSteps; // NEW

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
                // NEW: Show reasoning details if available
                if (!isUserMessage && reasoningSteps != null && reasoningSteps!.isNotEmpty)
                  ReasoningDetails(steps: reasoningSteps!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 5. Update ChatPanel to Render Streaming Messages
**File**: `lib/features/agent/presentation/components/chat_panel.dart`
**Changes**: Render both completed and streaming messages

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/agent_bloc.dart';
import '../../bloc/agent_event.dart';
import '../../bloc/agent_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/streaming_message_bubble.dart';
import '../widgets/text_composer.dart';

class ChatPanel extends StatelessWidget {
  const ChatPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        // Combine completed messages and streaming messages for display
        final allMessages = <Widget>[];

        // Add completed messages (in reverse for chat display)
        for (final message in state.messages.reversed) {
          // Check if this message has associated reasoning
          final messageId = message.hashCode.toString(); // Simplified ID lookup
          final streamingMessage = state.streamingMessages[messageId];

          allMessages.add(
            MessageBubble(
              message: message,
              reasoningSteps: streamingMessage?.reasoningSteps,
            ),
          );
        }

        // Add current streaming message if exists
        if (state.currentStreamingMessageId != null) {
          final streamingMessage = state.streamingMessages[state.currentStreamingMessageId!];
          if (streamingMessage != null) {
            allMessages.insert(0, StreamingMessageBubble(streamingMessage: streamingMessage));
          }
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 600),
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  reverse: true,
                  itemBuilder: (_, int index) => allMessages[index],
                  itemCount: allMessages.length,
                ),
              ),
              const Divider(height: 1.0),
              Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor),
                child: TextComposer(
                  onSubmitted: (text) {
                    context.read<AgentBloc>().add(SendMessage(text));
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

#### 6. Add intl Dependency
**File**: `pubspec.yaml`
**Changes**: Add intl package for timestamp formatting

```yaml
dependencies:
  # ... existing dependencies ...
  intl: ^0.19.0
```

Run: `flutter pub get`

### Success Criteria

#### Automated Verification:
- [ ] Code compiles without errors: `flutter analyze`
- [ ] Widget tests pass: `flutter test`
- [ ] No layout overflow errors in tests
- [ ] Accessibility labels present on interactive elements

#### Manual Verification:
- [ ] Send message and verify streaming message bubble appears
- [ ] Avatar shows spinner while streaming, 'A' when complete
- [ ] "typing..." indicator visible during streaming
- [ ] "Thinking..." text shown if no text chunks received yet
- [ ] "Show Details" button visible when reasoning steps exist
- [ ] Clicking "Show Details" expands reasoning section
- [ ] Reasoning steps displayed in chronological order with timestamps
- [ ] Icons and colors differentiate step types (thinking, tool use, error)
- [ ] Clicking "Hide Details" collapses reasoning section
- [ ] Badge shows count of reasoning steps
- [ ] Completed messages retain reasoning details after streaming ends
- [ ] Multiple messages with reasoning display correctly
- [ ] UI doesn't flicker during rapid updates
- [ ] Expandable sections maintain state during scroll
- [ ] Layout looks good on different screen sizes

**Implementation Note**: Test with various reasoning step counts (0, 1, 10, 50+) to ensure performance and layout scale well.

---

## Phase 5: Connect Streaming Text Display

### Overview
Wire up incremental text streaming using ArtifactUpdate events to display text chunks as they arrive.

### Changes Required

#### 1. Enhance Raw Event Processing for Artifacts
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Process ArtifactUpdate events for text streaming

```dart
Future<void> _onRawEventReceived(
  OnRawEventReceived event,
  Emitter<AgentState> emit,
) async {
  final rawEvent = event.event;

  if (rawEvent is StatusUpdate || rawEvent is TaskStatusUpdate) {
    // ... existing status update processing ...
  } else if (rawEvent is ArtifactUpdate) {
    // Handle streaming text via artifacts
    genUiLogger.info('Received ArtifactUpdate: ${rawEvent.artifactId}, append=${rawEvent.append}, lastChunk=${rawEvent.lastChunk}');

    if (rawEvent.append) {
      // This is an incremental text chunk
      for (final part in rawEvent.artifact.parts) {
        if (part is TextPart) {
          final text = part.text;
          if (text.isNotEmpty) {
            genUiLogger.fine('Adding text chunk (${text.length} chars): "${text.substring(0, text.length.clamp(0, 50))}..."');
            add(OnTextChunkReceived(rawEvent.taskId, text));
          }
        }
      }
    } else {
      // This is a complete artifact, not incremental
      // Could be the final complete text
      for (final part in rawEvent.artifact.parts) {
        if (part is TextPart) {
          final text = part.text;
          if (text.isNotEmpty) {
            genUiLogger.info('Received complete artifact text (${text.length} chars)');
            // Replace all chunks with complete text
            add(OnTextChunkReceived(rawEvent.taskId, text));
          }
        }
      }
    }

    if (rawEvent.lastChunk) {
      genUiLogger.info('Last chunk received for task ${rawEvent.taskId}, marking complete');
      add(OnStreamingMessageComplete(rawEvent.taskId));
    }
  }
}
```

#### 2. Handle Task Completion State
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Convert streaming message to final ChatMessage

```dart
Future<void> _onStreamingMessageComplete(
  OnStreamingMessageComplete event,
  Emitter<AgentState> emit,
) async {
  final messageId = event.messageId;

  final currentStreamingMessages = Map<String, StreamingMessage>.from(state.streamingMessages);
  final streamingMessage = currentStreamingMessages[messageId];

  if (streamingMessage != null) {
    // Mark as complete
    currentStreamingMessages[messageId] = streamingMessage.copyWith(isComplete: true);

    // If there's text, create a ChatMessage and add to messages list
    final fullText = streamingMessage.fullText;
    List<ChatMessage>? updatedMessages;

    if (fullText.isNotEmpty) {
      updatedMessages = [
        ...state.messages,
        AiTextMessage(text: fullText),
      ];

      genUiLogger.info('Streaming message complete. Added to messages: "$fullText"');
    }

    emit(state.copyWith(
      streamingMessages: currentStreamingMessages,
      messages: updatedMessages,
      status: ConnectionStatus.initial,
      currentStreamingMessageId: null, // Clear current streaming ID
    ));
  }
}
```

#### 3. Add Text Chunk Throttling
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Throttle rapid text chunk updates to prevent UI thrashing

```dart
import 'dart:async';

class AgentBloc extends Bloc<AgentEvent, AgentState> {
  // ... existing fields ...

  Timer? _textChunkThrottleTimer;
  final Map<String, List<String>> _pendingTextChunks = {};
  static const _textChunkThrottleDuration = Duration(milliseconds: 50);

  // ... existing methods ...

  Future<void> _onTextChunkReceived(
    OnTextChunkReceived event,
    Emitter<AgentState> emit,
  ) async {
    final messageId = event.messageId;
    final chunk = event.textChunk;

    // Add chunk to pending buffer
    _pendingTextChunks.putIfAbsent(messageId, () => []).add(chunk);

    // Throttle updates to avoid excessive rebuilds
    _textChunkThrottleTimer?.cancel();
    _textChunkThrottleTimer = Timer(_textChunkThrottleDuration, () {
      _flushPendingTextChunks(messageId, emit);
    });
  }

  void _flushPendingTextChunks(String messageId, Emitter<AgentState> emit) {
    final pendingChunks = _pendingTextChunks.remove(messageId);
    if (pendingChunks == null || pendingChunks.isEmpty) return;

    final currentStreamingMessages = Map<String, StreamingMessage>.from(state.streamingMessages);

    final existingMessage = currentStreamingMessages[messageId] ?? StreamingMessage(
      messageId: messageId,
      timestamp: DateTime.now(),
    );

    currentStreamingMessages[messageId] = existingMessage.copyWith(
      textChunks: [...existingMessage.textChunks, ...pendingChunks],
    );

    emit(state.copyWith(
      streamingMessages: currentStreamingMessages,
      currentStreamingMessageId: messageId,
    ));
  }

  @override
  Future<void> close() {
    _textChunkThrottleTimer?.cancel();
    _surfaceSubscription?.cancel();
    // ... rest of cleanup ...
    return super.close();
  }
}
```

#### 4. Handle Fallback for Non-Streaming Servers
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Show generic "processing" if no intermediate events

```dart
Future<void> _onSendMessage(
  SendMessage event,
  Emitter<AgentState> emit,
) async {
  if (event.text.trim().isEmpty) return;

  emit(state.copyWith(status: ConnectionStatus.streaming));

  // Create a new streaming message entry
  final messageId = DateTime.now().millisecondsSinceEpoch.toString();
  final streamingMessages = Map<String, StreamingMessage>.from(state.streamingMessages);
  streamingMessages[messageId] = StreamingMessage(
    messageId: messageId,
    timestamp: DateTime.now(),
    reasoningSteps: [
      // Add default "processing" step as fallback
      ReasoningStep(
        timestamp: DateTime.now(),
        description: 'Processing your request...',
        type: ReasoningStepType.status,
      ),
    ],
  );

  emit(state.copyWith(
    streamingMessages: streamingMessages,
    currentStreamingMessageId: messageId,
  ));

  // Send the message and listen to raw events
  _sendMessageWithRawEvents(event.text, messageId);
}
```

### Success Criteria

#### Automated Verification:
- [ ] Code compiles: `flutter analyze`
- [ ] No memory leaks from timers: run app with leak detection
- [ ] Text concatenation is efficient (no O(n²) string building)
- [ ] State updates complete within 16ms (60fps target)

#### Manual Verification:
- [ ] Send message to server that supports ArtifactUpdate streaming
- [ ] Text appears incrementally in message bubble as chunks arrive
- [ ] Text updates smoothly without flickering
- [ ] Reasoning steps accumulate alongside text chunks
- [ ] "typing..." indicator shows while streaming
- [ ] Message completes and moves to chat history when final chunk received
- [ ] Fallback "Processing..." step shows if server doesn't emit events
- [ ] Multiple rapid chunks don't cause UI lag
- [ ] Throttling prevents excessive rebuilds (check DevTools timeline)
- [ ] Long messages (1000+ chars) stream without performance issues
- [ ] Fast server responses (< 100ms chunks) display correctly
- [ ] Slow server responses (> 1s between chunks) display correctly

**Implementation Note**: Test with both streaming-capable and non-streaming servers. If your current server doesn't support ArtifactUpdate streaming, this phase will gracefully show generic status with final text response.

---

## Phase 6: Polish & Performance Optimization

### Overview
Add final polish including animations, performance optimizations, and edge case handling.

### Changes Required

#### 1. Add Typing Animation Effect
**File**: `lib/features/agent/presentation/widgets/streaming_message_bubble.dart`
**Changes**: Animate text cursor

```dart
class StreamingMessageBubble extends StatefulWidget {
  const StreamingMessageBubble({
    super.key,
    required this.streamingMessage,
  });

  final StreamingMessage streamingMessage;

  @override
  State<StreamingMessageBubble> createState() => _StreamingMessageBubbleState();
}

class _StreamingMessageBubbleState extends State<StreamingMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.streamingMessage.fullText;
    final isStreaming = !widget.streamingMessage.isComplete;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              child: widget.streamingMessage.isComplete
                  ? const Text('A')
                  : SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    const Text(
                      'Agent',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (isStreaming) ...[
                      const SizedBox(width: 8),
                      Text(
                        'typing...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: text.isNotEmpty
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(text)),
                            if (isStreaming)
                              FadeTransition(
                                opacity: _cursorController,
                                child: Container(
                                  width: 2,
                                  height: 16,
                                  color: theme.colorScheme.primary,
                                  margin: const EdgeInsets.only(left: 2),
                                ),
                              ),
                          ],
                        )
                      : Text(
                          'Thinking...',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                ),
                ReasoningDetails(steps: widget.streamingMessage.reasoningSteps),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

#### 2. Add Auto-Scroll to Latest Message
**File**: `lib/features/agent/presentation/components/chat_panel.dart`
**Changes**: Auto-scroll when new chunks arrive

```dart
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final ScrollController _scrollController = ScrollController();
  String? _lastStreamingMessageId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // reverse list, so 0 is bottom
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AgentBloc, AgentState>(
      listener: (context, state) {
        // Auto-scroll when streaming message changes
        if (state.currentStreamingMessageId != _lastStreamingMessageId) {
          _lastStreamingMessageId = state.currentStreamingMessageId;
          if (state.currentStreamingMessageId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
        }
      },
      child: BlocBuilder<AgentBloc, AgentState>(
        builder: (context, state) {
          // ... existing message list building ...

          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 600),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController, // Add controller
                    padding: const EdgeInsets.all(8.0),
                    reverse: true,
                    itemBuilder: (_, int index) => allMessages[index],
                    itemCount: allMessages.length,
                  ),
                ),
                const Divider(height: 1.0),
                Container(
                  decoration: BoxDecoration(color: Theme.of(context).cardColor),
                  child: TextComposer(
                    onSubmitted: (text) {
                      context.read<AgentBloc>().add(SendMessage(text));
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

#### 3. Optimize State Updates with Selective Rebuilds
**File**: `lib/features/agent/presentation/components/chat_panel.dart`
**Changes**: Use BlocBuilder with buildWhen

```dart
@override
Widget build(BuildContext context) {
  return BlocListener<AgentBloc, AgentState>(
    listener: (context, state) {
      // ... auto-scroll logic ...
    },
    child: BlocBuilder<AgentBloc, AgentState>(
      buildWhen: (previous, current) {
        // Only rebuild if messages or streaming state changed
        return previous.messages != current.messages ||
               previous.streamingMessages != current.streamingMessages ||
               previous.currentStreamingMessageId != current.currentStreamingMessageId;
      },
      builder: (context, state) {
        // ... build UI ...
      },
    ),
  );
}
```

#### 4. Add Error Handling for Malformed Events
**File**: `lib/features/agent/bloc/agent_bloc.dart`
**Changes**: Handle parsing errors gracefully

```dart
Future<void> _onRawEventReceived(
  OnRawEventReceived event,
  Emitter<AgentState> emit,
) async {
  try {
    final rawEvent = event.event;

    // ... existing event processing ...
  } catch (e, stackTrace) {
    genUiLogger.severe('Error processing raw event: $e', e, stackTrace);

    // Add error step to current streaming message
    if (state.currentStreamingMessageId != null) {
      add(OnReasoningStepAdded(
        state.currentStreamingMessageId!,
        ReasoningStep(
          timestamp: DateTime.now(),
          description: 'Error processing event: ${e.toString()}',
          type: ReasoningStepType.error,
        ),
      ));
    }
  }
}
```

#### 5. Add Reasoning Step Limit
**File**: `lib/features/agent/models/streaming_message.dart`
**Changes**: Limit stored reasoning steps to prevent memory issues

```dart
class StreamingMessage extends Equatable {
  const StreamingMessage({
    required this.messageId,
    this.textChunks = const [],
    this.reasoningSteps = const [],
    this.isComplete = false,
    this.timestamp,
  });

  static const int maxReasoningSteps = 100;

  // ... existing fields and methods ...

  StreamingMessage copyWith({
    List<String>? textChunks,
    List<ReasoningStep>? reasoningSteps,
    bool? isComplete,
  }) {
    // Limit reasoning steps to prevent memory bloat
    final limitedSteps = reasoningSteps ?? this.reasoningSteps;
    final finalSteps = limitedSteps.length > maxReasoningSteps
        ? limitedSteps.sublist(limitedSteps.length - maxReasoningSteps)
        : limitedSteps;

    return StreamingMessage(
      messageId: messageId,
      textChunks: textChunks ?? this.textChunks,
      reasoningSteps: finalSteps,
      isComplete: isComplete ?? this.isComplete,
      timestamp: timestamp,
    );
  }

  // ... rest of class ...
}
```

#### 6. Add Accessibility Labels
**File**: `lib/features/agent/presentation/widgets/reasoning_details.dart`
**Changes**: Add semantic labels for screen readers

```dart
@override
Widget build(BuildContext context) {
  if (widget.steps.isEmpty) {
    return const SizedBox.shrink();
  }

  final theme = Theme.of(context);

  return Semantics(
    label: 'Reasoning details. ${widget.steps.length} steps. ${_isExpanded ? "Expanded" : "Collapsed"}',
    button: true,
    child: Container(
      // ... existing container ...
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            // ... existing InkWell content ...
          ),
          if (_isExpanded)
            // ... existing expanded content ...
        ],
      ),
    ),
  );
}
```

### Success Criteria

#### Automated Verification:
- [ ] Code compiles: `flutter analyze`
- [ ] No performance warnings in DevTools
- [ ] Memory usage stable with long conversations (test with 50+ messages)
- [ ] No dropped frames during streaming (check Flutter timeline)
- [ ] Accessibility tests pass: `flutter test --tags=accessibility`

#### Manual Verification:
- [ ] Typing cursor animates smoothly during streaming
- [ ] Cursor disappears when streaming completes
- [ ] Chat auto-scrolls to show new streaming message
- [ ] Auto-scroll works correctly with manual scroll intervention
- [ ] buildWhen prevents unnecessary rebuilds (verify in DevTools)
- [ ] Error events display properly in reasoning details
- [ ] App doesn't crash with malformed events
- [ ] Reasoning steps limited to 100 per message
- [ ] Screen reader announces "Reasoning details" when focused
- [ ] Expandable button accessible via keyboard navigation
- [ ] Smooth scrolling on low-end devices
- [ ] No memory leaks after 10+ message exchanges
- [ ] Performance good with 5+ concurrent reasoning steps per message

**Implementation Note**: Test on a physical device with slower CPU to ensure animations remain smooth at 60fps. Use Flutter DevTools performance overlay.

---

## Testing Strategy

### Unit Tests

**StreamingMessage Model Tests** (`test/models/streaming_message_test.dart`):
- Test fullText concatenates chunks correctly
- Test copyWith preserves immutability
- Test reasoning step limit (max 100 steps)
- Test Equatable properties

**AgentBloc Tests** (`test/bloc/agent_bloc_test.dart`):
- Test OnRawEventReceived processing for StatusUpdate
- Test OnRawEventReceived processing for ArtifactUpdate
- Test OnTextChunkReceived accumulates chunks
- Test OnReasoningStepAdded accumulates steps
- Test OnStreamingMessageComplete transitions message
- Test state transitions: initial → streaming → initial
- Test error handling in raw event processing

### Widget Tests

**ReasoningStepWidget Tests** (`test/widgets/reasoning_step_widget_test.dart`):
- Test renders timestamp, icon, and description
- Test different icons for different step types
- Test color coding by step type

**ReasoningDetails Tests** (`test/widgets/reasoning_details_test.dart`):
- Test expand/collapse functionality
- Test step count badge
- Test empty state (no steps)
- Test accessibility labels

**StreamingMessageBubble Tests** (`test/widgets/streaming_message_bubble_test.dart`):
- Test shows spinner during streaming
- Test shows 'A' avatar when complete
- Test "typing..." indicator
- Test "Thinking..." fallback text
- Test cursor animation

### Integration Tests

**End-to-End Streaming Flow** (`integration_test/streaming_flow_test.dart`):
1. Initialize agent
2. Send message
3. Verify streaming message appears
4. Verify reasoning steps accumulate
5. Verify text chunks accumulate
6. Verify message completes
7. Verify message added to chat history
8. Verify reasoning details persist

### Manual Testing Steps

1. **Basic Streaming Flow**:
   - Start app
   - Send message: "Hello, can you help me?"
   - Verify streaming message appears with spinner
   - Verify "typing..." indicator shows
   - Verify reasoning steps appear (if server supports)
   - Verify text streams in (if server supports)
   - Verify message completes and moves to history

2. **Expandable Details**:
   - Send message that generates reasoning steps
   - Click "Show Details"
   - Verify steps display in chronological order
   - Verify timestamps formatted correctly
   - Verify icons and colors differentiate step types
   - Click "Hide Details"
   - Verify section collapses

3. **Multiple Messages**:
   - Send 5 consecutive messages rapidly
   - Verify each message streams independently
   - Verify no overlapping or confused state
   - Verify all messages retain reasoning after completion

4. **Edge Cases**:
   - Send empty message (should be blocked)
   - Send very long message (1000+ chars)
   - Send message to unresponsive server (timeout)
   - Verify error handling displays gracefully

5. **Performance**:
   - Send message that generates 50+ reasoning steps
   - Verify no UI lag or stuttering
   - Scroll through long conversation (20+ messages)
   - Verify smooth scrolling
   - Check memory usage in DevTools

## Performance Considerations

### Throttling Strategy
- Text chunk updates throttled to 50ms intervals
- Prevents UI thrashing from rapid events
- Balances responsiveness with performance

### Memory Management
- Reasoning steps limited to 100 per message
- Old streaming messages cleaned up after completion
- Stream controllers properly disposed
- Timers cancelled on dispose

### Render Optimization
- Use buildWhen to prevent unnecessary rebuilds
- ListView.builder for efficient list rendering
- Const constructors where possible
- Minimize widget tree depth in message bubbles

### State Immutability
- All state updates via copyWith (immutable)
- Use Map.from for map updates
- Spread operator for list updates
- Ensures predictable state transitions

## Migration Notes

### Breaking Changes
- None. This is purely additive functionality.

### Backward Compatibility
- Existing message display continues to work
- Falls back gracefully if server doesn't emit intermediate events
- No changes to A2A protocol or connector contracts

### Graceful Degradation
- If server doesn't support streaming: shows generic "Processing..." status
- If server doesn't emit reasoning: shows only final text
- If ArtifactUpdate not used: displays complete text at end

## References

- A2A Protocol Specification: https://a2ui.org/a2a-extension
- GenUI Package: https://pub.dev/packages/genui
- A2UI Package: https://pub.dev/packages/genui_a2ui
- BLoC Pattern Documentation: https://bloclibrary.dev/
- Flutter Performance Best Practices: https://flutter.dev/docs/perf/best-practices
