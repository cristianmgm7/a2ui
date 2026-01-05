#!/bin/bash
# Start the ADK A2A server with A2UI integration

echo "Starting ADK A2A server with A2UI integration..."
echo "Server will be available at http://localhost:8000"
echo "Agent card will be available at http://localhost:8000/.well-known/agent-card.json"
echo ""

# Activate virtual environment and start server
source /Users/cristian/Documents/tech/agent/.venv/bin/activate

echo "Starting A2A server..."
echo ""
echo "Current environment variables:"
echo "  GOOGLE_API_KEY: ${GOOGLE_API_KEY:+SET (hidden)} ${GOOGLE_API_KEY:-NOT SET}"
echo "  GOOGLE_CLOUD_PROJECT: ${GOOGLE_CLOUD_PROJECT:-NOT SET}"
echo "  GOOGLE_CLOUD_LOCATION: ${GOOGLE_CLOUD_LOCATION:-NOT SET}"
echo ""

# Set Python path and run from project root
cd /Users/cristian/Documents/tech/a2ui
PYTHONPATH=/Users/cristian/Documents/tech/a2ui/agent python3 -m uvicorn agent.agent:a2a_app --host 127.0.0.1 --port 8000

