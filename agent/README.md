# A2UI Agent Server

This directory contains the ADK agent that powers the A2UI Flutter application.

## Prerequisites

- Python 3.x
- Google ADK installed (`pip install google-adk`)
- Google AI API key or Google Cloud project configured

### Authentication Setup

The agent requires Google AI authentication. The agent automatically loads credentials from a `.env` file in the `agent/agent/` directory.

#### Setup
1. Create a `.env` file in the `agent/agent/` directory
2. Add one of the following:

**Option 1: Google AI API (Recommended for testing)**
```bash
GOOGLE_API_KEY=your_api_key_here
```
Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)

**Option 2: Google Cloud Vertex AI**
```bash
GOOGLE_CLOUD_PROJECT=your_project_id
GOOGLE_CLOUD_LOCATION=us-central1
```

#### Alternative: Interactive Setup
Run the interactive setup script:
```bash
cd /Users/cristian/Documents/tech/a2ui/agent
./setup_auth.sh
```

## Starting the Server

### Option 1: Using the startup script
```bash
cd /Users/cristian/Documents/tech/a2ui/agent
./start_server.sh
```

### Option 2: Manual start
```bash
cd /Users/cristian/Documents/tech/a2ui/agent
adk api_server --a2a --port 8000
```

**Important**: The `--a2a` flag is **required** for A2UI integration. It exposes the agent card at `/.well-known/agent-card.json` which the Flutter client needs to discover the agent's capabilities.

## Verifying the Server

Once the server is running, you can verify it's working by:

1. **Check the agent card:**
   ```bash
   curl http://localhost:8000/.well-known/agent-card.json
   ```

2. **Check the server health:**
   ```bash
   curl http://localhost:8000/health
   ```

## Agent Configuration

The main agent is defined in `agent/agent.py`:
- `root_agent`: Main orchestrator that coordinates all sub-agents
- Sub-agents: GitHub, Carbon Voice, Atlassian, Google Calendar

## Connecting the Flutter Client

The Flutter app (`lib/main.dart`) is already configured to connect to `http://localhost:8000`. Make sure:
1. The server is running with `--a2a` flag
2. Your Flutter app has network permissions (already configured for macOS)
3. Both server and client are running on the same machine

## Troubleshooting

### Agent Card 404 Error
If you see `Failed to fetch Agent Card from http://localhost:8000/.well-known/agent-card.json: 404`:
- Make sure you're using the `--a2a` flag when starting the server
- Restart the server using `./start_server.sh`

### Connection Refused
If the Flutter app can't connect:
- Verify the server is running: `curl http://localhost:8000`
- Check the port number matches in both server and Flutter app
- Ensure macOS network permissions are set (already configured)

