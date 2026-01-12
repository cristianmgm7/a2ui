import 'package:a2ui/core/theme/app_colors.dart';
import 'package:a2ui/features/agent/genui/models/task_info.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Displays a single task's progress through its lifecycle.
///
/// Shows the task state, status messages (thinking steps), and artifacts.
/// Each task is tracked individually by its ID.
class TaskBubble extends StatefulWidget {
  /// Creates a [TaskBubble].
  const TaskBubble({
    required this.task,
    super.key,
  });

  /// The task information to display
  final TaskInfo task;

  @override
  State<TaskBubble> createState() => _TaskBubbleState();
}

class _TaskBubbleState extends State<TaskBubble>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Start expanded for active tasks
    _isExpanded = widget.task.isActive;

    // Pulse animation for active tasks
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.task.isActive) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(TaskBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-expand when task becomes active
    if (widget.task.isActive && !oldWidget.task.isActive) {
      setState(() => _isExpanded = true);
      _pulseController.repeat();
    }

    // Stop pulse when task becomes terminal
    if (widget.task.isTerminal && !oldWidget.task.isTerminal) {
      _pulseController.stop();
    }

    // Auto-expand if new status messages are added
    if (widget.task.statusMessages.length > oldWidget.task.statusMessages.length) {
      setState(() => _isExpanded = true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          border: Border.all(
            color: _getBorderColor(),
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
                  // State indicator icon
                  _buildStateIcon(),

                  const SizedBox(width: 8),

                  // Title
                  Text(
                    _getStateTitle(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _getTitleColor(),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Status message count
                  if (widget.task.statusMessages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getBadgeBackgroundColor(),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getBadgeBorderColor(),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${widget.task.statusMessages.length} step${widget.task.statusMessages.length > 1 ? "s" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getBadgeTextColor(),
                        ),
                      ),
                    ),

                  const SizedBox(width: 4),

                  // Artifact count
                  if (widget.task.artifacts.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.paperclip(),
                            size: 11,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${widget.task.artifacts.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                        ],
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

            // Expanded content
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),

              // Status messages list (thinking steps)
              if (widget.task.statusMessages.isNotEmpty) ...[
                ...widget.task.statusMessages.map((msg) => Padding(
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
                          msg.text,
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
                const SizedBox(height: 4),
              ],

              // Artifacts section
              if (widget.task.artifacts.isNotEmpty) ...[
                const Text(
                  'Artifacts:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ...widget.task.artifacts.map((artifact) => _buildArtifactItem(artifact)),
              ],

              // Error message
              if (widget.task.errorMessage != null) ...[
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
                        widget.task.errorMessage!,
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

              // Task ID (for debugging)
              const SizedBox(height: 8),
              Text(
                'Task ID: ${widget.task.taskId.substring(0, 8)}...',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStateIcon() {
    switch (widget.task.state) {
      case TaskLifecycleState.submitted:
        return Icon(
          PhosphorIcons.clockCounterClockwise(),
          size: 16,
          color: AppColors.textSecondary,
        );
      case TaskLifecycleState.working:
        return FadeTransition(
          opacity: _pulseController,
          child: Icon(
            PhosphorIcons.brain(),
            size: 16,
            color: AppColors.primary,
          ),
        );
      case TaskLifecycleState.completed:
        return Icon(
          PhosphorIcons.checkCircle(),
          size: 16,
          color: AppColors.success,
        );
      case TaskLifecycleState.failed:
        return Icon(
          PhosphorIcons.xCircle(),
          size: 16,
          color: AppColors.error,
        );
      case TaskLifecycleState.canceled:
        return Icon(
          PhosphorIcons.prohibit(),
          size: 16,
          color: AppColors.textSecondary,
        );
      case TaskLifecycleState.rejected:
        return Icon(
          PhosphorIcons.warningCircle(),
          size: 16,
          color: AppColors.warning,
        );
      case TaskLifecycleState.inputRequired:
        return Icon(
          PhosphorIcons.questionMark(),
          size: 16,
          color: AppColors.warning,
        );
      case TaskLifecycleState.authRequired:
        return Icon(
          PhosphorIcons.lock(),
          size: 16,
          color: AppColors.warning,
        );
      case TaskLifecycleState.unknown:
        return Icon(
          PhosphorIcons.question(),
          size: 16,
          color: AppColors.textSecondary,
        );
    }
  }

  String _getStateTitle() {
    switch (widget.task.state) {
      case TaskLifecycleState.submitted:
        return 'Task Submitted';
      case TaskLifecycleState.working:
        return 'Working...';
      case TaskLifecycleState.completed:
        return 'Task Completed';
      case TaskLifecycleState.failed:
        return 'Task Failed';
      case TaskLifecycleState.canceled:
        return 'Task Canceled';
      case TaskLifecycleState.rejected:
        return 'Task Rejected';
      case TaskLifecycleState.inputRequired:
        return 'Input Required';
      case TaskLifecycleState.authRequired:
        return 'Auth Required';
      case TaskLifecycleState.unknown:
        return 'Task Status Unknown';
    }
  }

  Color _getBackgroundColor() {
    switch (widget.task.state) {
      case TaskLifecycleState.failed:
        return AppColors.error.withValues(alpha: 0.1);
      case TaskLifecycleState.rejected:
      case TaskLifecycleState.inputRequired:
      case TaskLifecycleState.authRequired:
        return AppColors.warning.withValues(alpha: 0.1);
      default:
        return AppColors.surface;
    }
  }

  Color _getBorderColor() {
    switch (widget.task.state) {
      case TaskLifecycleState.failed:
        return AppColors.error.withValues(alpha: 0.3);
      case TaskLifecycleState.rejected:
      case TaskLifecycleState.inputRequired:
      case TaskLifecycleState.authRequired:
        return AppColors.warning.withValues(alpha: 0.3);
      default:
        return AppColors.border;
    }
  }

  Color _getTitleColor() {
    switch (widget.task.state) {
      case TaskLifecycleState.failed:
        return AppColors.error;
      case TaskLifecycleState.rejected:
      case TaskLifecycleState.inputRequired:
      case TaskLifecycleState.authRequired:
        return AppColors.warning;
      default:
        return AppColors.textPrimary;
    }
  }

  Color _getBadgeBackgroundColor() {
    if (widget.task.isActive) {
      return AppColors.primary.withValues(alpha: 0.1);
    }
    return AppColors.success.withValues(alpha: 0.1);
  }

  Color _getBadgeBorderColor() {
    if (widget.task.isActive) {
      return AppColors.primary.withValues(alpha: 0.3);
    }
    return AppColors.success.withValues(alpha: 0.3);
  }

  Color _getBadgeTextColor() {
    if (widget.task.isActive) {
      return AppColors.primary;
    }
    return AppColors.success;
  }

  Widget _buildArtifactItem(dynamic artifact) {
    // Placeholder for now - will be enhanced with proper artifact rendering
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.file(),
            size: 16,
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artifact.name ?? 'Artifact ${artifact.artifactId.substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (artifact.description != null)
                  Text(
                    artifact.description!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
