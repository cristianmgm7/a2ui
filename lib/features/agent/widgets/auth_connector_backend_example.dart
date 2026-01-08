/// Example demonstrating how the Python backend should send surfaceUpdate messages
/// with the correct catalog ID for the AuthConnector widget to work.

/// IMPORTANT: The backend MUST specify the catalog ID in surfaceUpdate messages
/// so that the Flutter app knows which catalog contains the AuthConnector widget.

/// CORRECT Backend Response (with catalog ID):
const String carbonVoiceAuthWithCatalogExample = '''
{
  "surfaceUpdate": {
    "surfaceId": "main_chat",
    "catalogId": "com.a2ui.auth-catalog-v1",
    "components": [
      {
        "id": "carbon_voice_auth",
        "component": "AuthConnector",
        "data": {
          "serviceName": "Carbon Voice",
          "authUrl": "https://api.carbonvoice.app/oauth/authorize?client_id=YOUR_CLIENT_ID&scope=files:read+files:write&response_type=code",
          "description": "I need access to your Carbon Voice conversations to list your messages."
        }
      }
    ]
  }
}
''';

/// INCORRECT Backend Response (missing catalog ID):
/// This won't work because the Flutter app doesn't know which catalog contains AuthConnector
const String carbonVoiceAuthWithoutCatalogExample = '''
{
  "surfaceUpdate": {
    "surfaceId": "main_chat",
    "components": [
      {
        "id": "carbon_voice_auth",
        "component": "AuthConnector",
        "data": {
          "serviceName": "Carbon Voice",
          "authUrl": "https://api.carbonvoice.app/oauth/authorize?client_id=YOUR_CLIENT_ID&scope=files:read+files:write",
          "description": "I need access to your Carbon Voice conversations."
        }
      }
    ]
  }
}
''';

/// Python Backend Helper Function:
///
/// ```python
/// import json
///
/// def create_auth_connector_response(service_name, auth_url, reason):
///     """Create a surfaceUpdate message with the correct catalog ID."""
///     return json.dumps({
///         "surfaceUpdate": {
///             "surfaceId": "main_chat",
///             "catalogId": "com.a2ui.auth-catalog-v1",  # CRITICAL: Must match Flutter catalog ID
///             "components": [
///                 {
///                     "id": f"{service_name.lower().replace(' ', '_')}_auth",
///                     "component": "AuthConnector",
///                     "data": {
///                         "serviceName": service_name,
///                         "authUrl": auth_url,
///                         "description": reason
///                     }
///                 }
///             ]
///         }
///     })
///
/// # Example usage:
/// carbon_voice_auth = create_auth_connector_response(
///     "Carbon Voice",
///     "https://api.carbonvoice.app/oauth/authorize?client_id=HUQR5D01MSRFMFFT5uFGADjndELzoaBQKYxdr&scope=files:read+files:write",
///     "I need access to your Carbon Voice conversations to list your messages."
/// )
/// ```

