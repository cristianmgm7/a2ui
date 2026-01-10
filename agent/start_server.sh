#!/bin/bash
# Start the ADK A2A server with A2UI integration

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Starting ADK A2A server with A2UI integration..."
echo "Server will be available at http://localhost:8000"
echo "Agent card will be available at http://localhost:8000/.well-known/agent-card.json"
echo ""

# Check if virtual environment exists
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "Virtual environment not found. Creating one..."
    python3 -m venv "$SCRIPT_DIR/.venv"
    echo "Installing dependencies..."
    source "$SCRIPT_DIR/.venv/bin/activate"
    pip install --upgrade pip
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        pip install -r "$SCRIPT_DIR/requirements.txt"
    else
        echo "Warning: requirements.txt not found. Please install dependencies manually."
    fi
else
    # Activate virtual environment
    source "$SCRIPT_DIR/.venv/bin/activate"
fi

echo "Starting A2A server..."
echo ""
echo "Current environment variables:"
echo "  GOOGLE_API_KEY: ${GOOGLE_API_KEY:+SET (hidden)} ${GOOGLE_API_KEY:-NOT SET}"
echo "  GOOGLE_CLOUD_PROJECT: ${GOOGLE_CLOUD_PROJECT:-NOT SET}"
echo "  GOOGLE_CLOUD_LOCATION: ${GOOGLE_CLOUD_LOCATION:-NOT SET}"
echo ""

# Set Python path and run from project root
cd "$SCRIPT_DIR"
PYTHONPATH="$SCRIPT_DIR" python3 -m uvicorn agent.agent:a2a_app --host 127.0.0.1 --port 8000

