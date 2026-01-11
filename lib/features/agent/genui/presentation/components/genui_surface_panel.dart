// import 'package:a2ui/core/theme/app_colors.dart';
// import 'package:a2ui/features/agent/genui/bloc/agent_bloc.dart';
// import 'package:a2ui/features/agent/genui/bloc/agent_state.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// /// Simple panel that shows connection status (no longer used for surfaces).
// ///
// /// This component has been simplified since we're using direct A2A chat
// /// instead of complex A2UI surface rendering.
// class GenUiSurfacePanel extends StatelessWidget {
//   /// Creates a [GenUiSurfacePanel].
//   const GenUiSurfacePanel({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<AgentBloc, AgentState>(
//       builder: (context, state) {
//         return Expanded(
//           child: ColoredBox(
//             color: AppColors.surface,
//             child: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     state.status == ConnectionStatus.streaming
//                         ? Icons.cloud_sync_outlined
//                         : Icons.cloud_done_outlined,
//                     size: 64,
//                     color: state.status == ConnectionStatus.streaming
//                         ? AppColors.primary
//                         : AppColors.success,
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     state.status == ConnectionStatus.streaming
//                         ? 'Agent is typing...'
//                         : 'Connected to A2A Agent',
//                     style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                           color: AppColors.textSecondary,
//                         ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Messages: ${state.messages.length}',
//                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           color: AppColors.textSecondary,
//                         ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
