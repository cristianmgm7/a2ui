import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:url_launcher/url_launcher.dart';

/// Schema defining the data structure for the generic auth connector widget.
/// This widget can handle authentication for any service (GitHub, Jira, Google, etc.)
final authSchema = S.object(
  properties: {
    'serviceName': S.string(description: 'The name of the service (e.g., Jira, GitHub, Carbon Voice)'),
    'authUrl': S.string(description: 'The full OAuth URL for the user to click'),
    'description': S.string(description: 'A short explanation of why auth is needed'),
  },
  required: ['serviceName', 'authUrl'],
);

/// Generic authentication connector widget that can handle any service.
/// The agent dynamically fills this widget with service-specific details.
final authConnectorWidget = CatalogItem(
  name: 'AuthConnector',
  dataSchema: authSchema,
  widgetBuilder: (itemContext) {
    final dataMap = itemContext.data as Map<String, dynamic>;
    final serviceName = dataMap['serviceName'] as String;
    final authUrl = dataMap['authUrl'] as String;
    final description = dataMap['description'] as String? ?? 'Connect your account to continue.';

    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_person, size: 24.0),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connect to $serviceName',
                          style: Theme.of(itemContext.buildContext).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          description,
                          style: Theme.of(itemContext.buildContext).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              ElevatedButton.icon(
                onPressed: () async {
                  // Launch the OAuth URL in the user's browser
                  final uri = Uri.parse(authUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }

                  // Dispatch event to notify the agent that auth flow was initiated
                  itemContext.dispatchEvent(UiEvent.fromMap({
                    'surfaceId': itemContext.surfaceId,
                    'widgetId': itemContext.id,
                    'eventType': 'auth_initiated',
                    'isAction': true,
                    'value': {
                      'serviceName': serviceName,
                      'authUrl': authUrl,
                    },
                    'timestamp': DateTime.now().toIso8601String(),
                  }));
                },
                icon: const Icon(Icons.open_in_browser),
                label: Text('Authorize $serviceName'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
