import 'dart:async';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';
import 'package:genui_a2ui/genui_a2ui.dart';

import 'agent_event.dart';
import 'agent_state.dart';

/// BLoC for managing the agent's state and interactions.
class AgentBloc extends Bloc<AgentEvent, AgentState> {
  /// Creates an [AgentBloc].
  AgentBloc({
    Uri? serverUrl,
  })  : _serverUrl = serverUrl ?? Uri.parse('http://localhost:8000'),
        super(const AgentState()) {
    on<InitializeAgent>(_onInitializeAgent);
    on<SendMessage>(_onSendMessage);
    on<OnProtocolUpdate>(_onProtocolUpdate);
    on<OnMessagesUpdated>(_onMessagesUpdated);
    on<SwitchSurface>(_onSwitchSurface);
    on<NextSurface>(_onNextSurface);
    on<PreviousSurface>(_onPreviousSurface);
  }

  final Uri _serverUrl;

  late final A2uiMessageProcessor _a2uiMessageProcessor;
  late final A2uiContentGenerator _contentGenerator;
  late final GenUiConversation _genUiConversation;

  StreamSubscription<GenUiUpdate>? _surfaceSubscription;
  VoidCallback? _conversationListener;

  /// Returns the A2uiMessageProcessor for use by the UI.
  A2uiMessageProcessor get messageProcessor => _a2uiMessageProcessor;

  Future<void> _onInitializeAgent(
    InitializeAgent event,
    Emitter<AgentState> emit,
  ) async {
    emit(state.copyWith(status: ConnectionStatus.loading));

    try {
      _a2uiMessageProcessor = A2uiMessageProcessor(
        catalogs: [CoreCatalogItems.asCatalog()],
      );

      _contentGenerator = A2uiContentGenerator(
        serverUrl: _serverUrl,
      );

      _genUiConversation = GenUiConversation(
        contentGenerator: _contentGenerator,
        a2uiMessageProcessor: _a2uiMessageProcessor,
      );

      // Initialize with existing surfaces
      final existingSurfaceIds = List<String>.from(state.surfaceIds);
      for (final id in _a2uiMessageProcessor.surfaces.keys) {
        if (!existingSurfaceIds.contains(id)) {
          existingSurfaceIds.add(id);
        }
      }

      // Listen to surface updates
      _surfaceSubscription = _a2uiMessageProcessor.surfaceUpdates.listen(
        (update) => add(OnProtocolUpdate(update)),
      );

      // Listen to conversation changes
      _conversationListener = () {
        add(OnMessagesUpdated(_genUiConversation.conversation.value));
      };
      _genUiConversation.conversation.addListener(_conversationListener!);

      emit(state.copyWith(
        status: ConnectionStatus.initial,
        surfaceIds: existingSurfaceIds,
        surfaces: Map.from(_a2uiMessageProcessor.surfaces),
      ));
    } catch (e) {
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

    emit(state.copyWith(status: ConnectionStatus.streaming));
    _genUiConversation.sendRequest(UserMessage.text(event.text));
  }

  void _onProtocolUpdate(
    OnProtocolUpdate event,
    Emitter<AgentState> emit,
  ) {
    final update = event.update;
    final currentSurfaceIds = List<String>.from(state.surfaceIds);

    if (update is SurfaceAdded) {
      genUiLogger.info('Surface added: ${update.surfaceId}');
      if (!currentSurfaceIds.contains(update.surfaceId)) {
        currentSurfaceIds.add(update.surfaceId);
        emit(state.copyWith(
          surfaceIds: currentSurfaceIds,
          currentSurfaceId: update.surfaceId,
          surfaces: Map.from(_a2uiMessageProcessor.surfaces),
          status: ConnectionStatus.streaming,
        ));
      }
    } else if (update is SurfaceUpdated) {
      genUiLogger.info('Surface updated: ${update.surfaceId}');
      emit(state.copyWith(
        surfaces: Map.from(_a2uiMessageProcessor.surfaces),
        status: ConnectionStatus.streaming,
      ));
    } else if (update is SurfaceRemoved) {
      genUiLogger.info('Surface removed: ${update.surfaceId}');
      if (currentSurfaceIds.contains(update.surfaceId)) {
        final removeIndex = currentSurfaceIds.indexOf(update.surfaceId);
        currentSurfaceIds.removeAt(removeIndex);

        String newCurrentSurfaceId = state.currentSurfaceId;
        if (currentSurfaceIds.isEmpty) {
          newCurrentSurfaceId = 'default';
        } else {
          final currentIndex = state.currentSurfaceIndex;
          if (currentIndex >= removeIndex && currentIndex > 0) {
            newCurrentSurfaceId = currentSurfaceIds[currentIndex - 1];
          } else if (currentIndex >= currentSurfaceIds.length) {
            newCurrentSurfaceId = currentSurfaceIds.last;
          }
        }

        emit(state.copyWith(
          surfaceIds: currentSurfaceIds,
          currentSurfaceId: newCurrentSurfaceId,
          surfaces: Map.from(_a2uiMessageProcessor.surfaces),
        ));
      }
    }
  }

  void _onMessagesUpdated(
    OnMessagesUpdated event,
    Emitter<AgentState> emit,
  ) {
    emit(state.copyWith(
      messages: event.messages,
      status: ConnectionStatus.initial,
    ));
  }

  void _onSwitchSurface(
    SwitchSurface event,
    Emitter<AgentState> emit,
  ) {
    if (state.surfaceIds.contains(event.surfaceId)) {
      emit(state.copyWith(currentSurfaceId: event.surfaceId));
    }
  }

  void _onNextSurface(
    NextSurface event,
    Emitter<AgentState> emit,
  ) {
    if (state.canNavigateNext) {
      final nextIndex = state.currentSurfaceIndex + 1;
      emit(state.copyWith(currentSurfaceId: state.surfaceIds[nextIndex]));
    }
  }

  void _onPreviousSurface(
    PreviousSurface event,
    Emitter<AgentState> emit,
  ) {
    if (state.canNavigatePrevious) {
      final previousIndex = state.currentSurfaceIndex - 1;
      emit(state.copyWith(currentSurfaceId: state.surfaceIds[previousIndex]));
    }
  }

  @override
  Future<void> close() {
    _surfaceSubscription?.cancel();
    if (_conversationListener != null) {
      _genUiConversation.conversation.removeListener(_conversationListener!);
    }
    _genUiConversation.dispose();
    _a2uiMessageProcessor.dispose();
    _contentGenerator.dispose();
    return super.close();
  }
}
