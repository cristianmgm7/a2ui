import 'package:equatable/equatable.dart';

/// Represents a single step in the agent's thinking/processing sequence.
///
/// These steps are displayed in real-time as the agent works through a task,
/// providing transparency into the agent's decision-making process.
class ThinkingStep extends Equatable {
  /// Creates a [ThinkingStep].
  const ThinkingStep({
    required this.message,
    required this.timestamp,
  });

  /// The thinking step message (e.g., "Analyzing your request...")
  final String message;

  /// When this step occurred
  final DateTime timestamp;

  @override
  List<Object?> get props => [message, timestamp];

  /// Creates a copy with optional field replacements
  ThinkingStep copyWith({
    String? message,
    DateTime? timestamp,
  }) {
    return ThinkingStep(
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
