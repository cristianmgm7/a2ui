// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';
import 'package:logging/logging.dart';

import 'features/agent/bloc/agent_bloc.dart';
import 'features/agent/bloc/agent_event.dart';
import 'features/agent/presentation/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureGenUiLogging(level: Level.ALL);
  runApp(const GenUIExampleApp());
}

/// The main application widget.
class GenUIExampleApp extends StatelessWidget {
  /// Creates a [GenUIExampleApp].
  const GenUIExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2UI Example',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: BlocProvider(
        create: (context) => AgentBloc()..add(const InitializeAgent()),
        child: const ChatScreen(),
      ),
    );
  }
}