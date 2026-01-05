# A2UI Integration - Current Status & Next Steps

## 🎯 Goal
Test the basic functionality of the `genui_a2ui` Flutter package with a simple question-answering agent.

## ✅ What We've Accomplished

1. **Fixed macOS Network Permissions** ✓
   - Added `com.apple.security.network.client` entitlement
   - Your Flutter app can now make network connections

2. **Installed A2A SDK** ✓
   - Installed `a2a-sdk` version 0.3.22
   - Installed with `pip install 'google-adk[a2a]'`

3. **Simplified the Agent** ✓
   - Removed all MCP tools (Carbon Voice, Atlassian, etc.)
   - Created a simple `qa_agent` with no external dependencies
   - Agent code is clean and minimal

4. **Agent Configuration** ✓
   - Exported `root_agent` properly in `__init__.py`
   - Created helper scripts and documentation

## ❌ Current Blocker

**The `--a2a` flag in ADK has a bug** that prevents the agent card from being exposed, even with our simplified agent. The error occurs in the ADK/FastAPI/Pydantic stack when trying to generate OpenAPI schemas.

**Error**: `PydanticSchemaGenerationError: Unable to generate pydantic-core schema for <class 'mcp.client.session.ClientSession'>`

This error appears to be in ADK's internal A2A implementation, not in our agent code.

## 🔧 Recommended Solutions

### Option 1: Use `adk web` Instead of `adk api_server --a2a` (RECOMMENDED)

The `adk web` command provides a web UI and might have better A2A support:

```bash
cd /Users/cristian/Documents/tech/a2ui/agent
source /Users/cristian/Documents/tech/agent/.venv/bin/activate
adk web --port 8000
```

Then check if the agent card is available at:
```
http://localhost:8000/.well-known/agent-card.json
```

### Option 2: Contact Google ADK Team

This appears to be a bug in the ADK's A2A implementation. Consider:
- Filing an issue on the [ADK GitHub repository](https://github.com/google/adk)
- Checking for ADK updates: `pip install --upgrade google-adk`
- Looking for known issues in the ADK documentation

### Option 3: Use a Different A2A Server Implementation

Instead of using ADK's built-in A2A server, you could:
1. Implement a custom FastAPI server that:
   - Serves the agent card at `/.well-known/agent-card.json`
   - Proxies requests to your ADK agent
   - Implements the A2UI protocol manually

### Option 4: Test with Flutter's A2A Mock Server

The `genui_a2ui` package might have example/mock servers for testing. Check:
```bash
cd /Users/cristian/Documents/tech/a2ui
flutter pub global activate genui_cli
# Look for example servers or testing utilities
```

## 📋 Files Modified

- `/Users/cristian/Documents/tech/a2ui/macos/Runner/DebugProfile.entitlements` - Added network permissions
- `/Users/cristian/Documents/tech/a2ui/macos/Runner/Release.entitlements` - Added network permissions  
- `/Users/cristian/Documents/tech/a2ui/agent/agent/__init__.py` - Exported root_agent
- `/Users/cristian/Documents/tech/a2ui/agent/agent/agent.py` - Simplified to basic QA agent
- `/Users/cristian/Documents/tech/a2ui/agent/start_server.sh` - Helper script (created)
- `/Users/cristian/Documents/tech/a2ui/agent/README.md` - Documentation (created)
- `/Users/cristian/Documents/tech/a2ui/agent/.well-known/agent-card.json` - Manual agent card (created, but not served)

## 🧪 Quick Test Commands

### Test Agent Works (CLI)
```bash
cd /Users/cristian/Documents/tech/a2ui/agent
source /Users/cristian/Documents/tech/agent/.venv/bin/activate
adk run agent
# Type a question and press Enter
```

### Test API Server (Without A2A)
```bash
cd /Users/cristian/Documents/tech/a2ui/agent
source /Users/cristian/Documents/tech/agent/.venv/bin/activate
adk api_server --port 8000
# Server runs but no agent card endpoint
```

### Test API Server (With A2A - Currently Broken)
```bash
cd /Users/cristian/Documents/tech/a2ui/agent
source /Users/cristian/Documents/tech/agent/.venv/bin/activate
adk api_server --a2a --port 8000
# Server runs but agent card returns 404
# OpenAPI endpoint returns 500 error
```

### Test Flutter App
```bash
cd /Users/cristian/Documents/tech/a2ui
flutter run -d macos
# App will fail to connect due to missing agent card
```

## 📚 Resources

- [ADK Documentation](https://google.github.io/adk-docs/)
- [ADK A2A Quickstart](https://google.github.io/adk-docs/a2a/quickstart-exposing/)
- [GenUI Flutter Documentation](https://docs.flutter.dev/ai/genui/get-started)
- [genui_a2ui Package](https://pub.dev/packages/genui_a2ui)
- [A2A Protocol Spec](https://github.com/google/adk/tree/main/a2a)

## 💡 Alternative Approach

If the ADK A2A server continues to have issues, you could:

1. **Create a simple FastAPI proxy server** that:
   - Serves a static agent card
   - Forwards requests to your ADK agent
   - Implements just enough of the A2UI protocol for testing

2. **Use the example from GenUI repository**:
   - Clone: https://github.com/flutter/genui
   - Look at `packages/genui_a2ui/example/`
   - See how they set up their test server

## 🎬 Immediate Next Step

**Try the `adk web` command** - it might have better A2A support than `adk api_server --a2a`:

```bash
cd /Users/cristian/Documents/tech/a2ui/agent
source /Users/cristian/Documents/tech/agent/.venv/bin/activate
adk web --port 8000
```

Then visit `http://localhost:8000` in your browser and check if there's an agent card endpoint.

---

**Current Agent**: Simple QA agent with no tools, ready for testing once A2A connection is established.

**Flutter App**: Configured and ready, just needs a working A2A server endpoint.

