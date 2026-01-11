import 'package:a2ui/core/theme/app_colors.dart';
import 'package:a2ui/features/agent/genui/models/thinking_step.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Displays the agent's thinking process in a collapsible bubble.
///
/// Shows real-time thinking steps while the agent is working, then
/// collapses to a compact view once the response is complete.
class ThinkingBubble extends StatefulWidget {
  /// Creates a [ThinkingBubble].
  const ThinkingBubble({
    required this.thinkingSteps,
    required this.isActive,
    this.error,
    super.key,
  });

  /// The list of thinking steps to display
  final List<ThinkingStep> thinkingSteps;

  /// Whether the agent is currently thinking (auto-expands if true)
  final bool isActive;

  /// Optional error message to display at the end
  final String? error;

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Start expanded if actively thinking, collapsed otherwise
    _isExpanded = widget.isActive;

    // Pulse animation for active thinking indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isActive) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(ThinkingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-expand when thinking starts
    if (widget.isActive && !oldWidget.isActive) {
      setState(() => _isExpanded = true);
      _pulseController.repeat();
    }

    // Auto-collapse when thinking completes
    if (!widget.isActive && oldWidget.isActive) {
      setState(() => _isExpanded = false);
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show thinking bubble if actively thinking, has steps, or has an error
    final shouldShow = widget.isActive || widget.thinkingSteps.isNotEmpty || widget.error != null;

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: widget.error != null
              ? AppColors.error.withValues(alpha: 0.1)
              : AppColors.surface,
          border: Border.all(
            color: widget.error != null
                ? AppColors.error.withValues(alpha: 0.3)
                : AppColors.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with toggle
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated thinking indicator
                  if (widget.isActive)
                    FadeTransition(
                      opacity: _pulseController,
                      child: Icon(
                        PhosphorIcons.brain(),
                        size: 16,
                        color: AppColors.primary,
                      ),
                    )
                  else if (widget.error != null)
                    Icon(
                      PhosphorIcons.warningCircle(),
                      size: 16,
                      color: AppColors.error,
                    )
                  else
                    Icon(
                      PhosphorIcons.checkCircle(),
                      size: 16,
                      color: AppColors.success,
                    ),

                  const SizedBox(width: 8),

                  // Title
                  Text(
                    widget.isActive
                        ? 'Thinking...'
                        : widget.error != null
                            ? 'Thinking (Failed)'
                            : 'Thinking',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.error != null
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Step count
                  if (widget.thinkingSteps.isNotEmpty)
                    Text(
                      '(${widget.thinkingSteps.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Expand/collapse icon
                  Icon(
                    _isExpanded
                        ? PhosphorIcons.caretUp()
                        : PhosphorIcons.caretDown(),
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),

            // Expanded thinking steps
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),

              // Thinking steps list
              ...widget.thinkingSteps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PhosphorIcons.dot(),
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        step.message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

              // Error message at the end
              if (widget.error != null) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PhosphorIcons.xCircle(),
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
