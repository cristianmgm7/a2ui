# A2UI Setup Status

## Summary

We've been working on connecting your Flutter A2UI app with your Google ADK agent backend. Here's what we've accomplished and what issues remain.

## ✅ Completed

### 1. macOS Network Permissions
- **Fixed**: Added `com.apple.security.network.client` entitlement to both:
  - `macos/Runner/DebugProfile.entitlements`
  - `macos/Runner/Release.entitlements`
- **Result**: Your Flutter app now has permission to make outgoing network connections on macOS

### 2. Installed A2A SDK
- **Installed**: `a2a-sdk` package (version 0.3.22) in your virtual environment
- **Location**: `/Users/cristian/Documents/tech/agent/.venv/`
- **Command used**: `pip install 'google-adk[a2a]'`

### 3. Agent Export Configuration
- **Updated**: `agent/agent/__init__.py` to properly export `root_agent`
- **Created**: `agent/start_server.sh` - A helper script to start the server with correct settings
- **Created**: `agent/README.md` - Documentation for running the agent server

### 4. Server Running
- **Status**: ADK API server is running successfully on `http://127.0.0.1:8000`
- **Command**: `adk api_server --port 8000` (currently running without `--a2a` flag)

## ❌ Current Issue

### Agent Card Not Accessible

**Problem**: When starting the server with `--a2a` flag, the agent card endpoint (`/.well-known/agent-card.json`) returns 404 Not Found.

**Root Cause**: There appears to be a compatibility issue between:
- The MCP tools in your agent (Carbon Voice, Atlassian agents)
- The Pydantic schema generation in FastAPI
- The A2A server implementation

**Error**: 
```
pydantic.errors.PydanticSchemaGenerationError: Unable to generate pydantic-core schema for <class 'mcp.client.session.ClientSession'>
```

## 🔧 Possible Solutions

### Option 1: Simplify the Agent (Recommended for Testing)
Create a minimal test agent without MCP tools to verify A2UI connection works:

```python
# test_agent.py
from google.adk.agents.llm_agent import Agent

test_agent = Agent(
    model='gemini-2.5-flash',
    name='test_agent',
    description='A simple test agent for A2UI',
    instruction='You are a helpful assistant. Respond to user queries clearly and concisely.',
    tools=[],  # No MCP tools for now
)
```

### Option 2: Wait for ADK/MCP Compatibility Fix
The issue might be resolved in a future version of `google-adk` or `mcp` packages.

### Option 3: Use Direct Agent Endpoint (Without Agent Card)
Some A2UI implementations might support direct agent endpoints without requiring the agent card discovery mechanism.

## 📝 Next Steps

1. **Test with Simplified Agent**:
   ```bash
   # Create a simple test agent without MCP tools
   # Start server with --a2a flag
   cd /Users/cristian/Documents/tech/a2ui/agent
   source /Users/cristian/Documents/tech/agent/.venv/bin/activate
   adk api_server --a2a --port 8000
   ```

2. **Verify Agent Card**:
   ```bash
   curl http://localhost:8000/.well-known/agent-card.json
   ```

3. **Test Flutter App**:
   ```bash
   cd /Users/cristian/Documents/tech/a2ui
   flutter run -d macos
   ```

## 📚 Resources

- [ADK A2A Documentation](https://google.github.io/adk-docs/a2a/quickstart-exposing/)
- [GenUI A2UI Package](https://github.com/flutter/genui/tree/main/packages/genui_a2ui)
- Agent Server: `http://localhost:8000`
- Agent Card (when working): `http://localhost:8000/.well-known/agent-card.json`

## 🐛 Known Issues

1. **MCP ClientSession Pydantic Schema**: The A2A server cannot generate OpenAPI schemas for agents that use MCP tools
2. **Agent Card 404**: The `--a2a` flag doesn't properly expose the agent card endpoint with the current agent configuration

## 💡 Workaround

Currently running the server **without** the `--a2a` flag:
```bash
adk api_server --port 8000
```

This allows the server to run, but the Flutter A2UI client requires the agent card for discovery, so the connection will fail with:
```
Failed to fetch Agent Card from http://localhost:8000/.well-known/agent-card.json: 404 : Not Found
```

