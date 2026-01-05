#!/bin/bash
# Setup script for Google AI API authentication

echo "🔧 Google AI API Authentication Setup"
echo "====================================="
echo ""

# Check if API key is already set
if [ -n "$GOOGLE_API_KEY" ]; then
    echo "✅ GOOGLE_API_KEY is already set"
    exit 0
fi

echo "Choose your authentication method:"
echo ""
echo "1) Google AI API (recommended for testing)"
echo "2) Google Cloud Vertex AI"
echo ""

read -p "Enter your choice (1 or 2): " choice

case $choice in
    1)
        echo ""
        echo "📝 Google AI API Setup"
        echo "======================"
        echo "1. Go to: https://makersuite.google.com/app/apikey"
        echo "2. Create a new API key (if you don't have one)"
        echo "3. Copy your API key"
        echo ""
        read -p "Paste your Google AI API key: " api_key
        echo ""
        echo "Setting GOOGLE_API_KEY..."
        export GOOGLE_API_KEY="$api_key"
        echo "✅ GOOGLE_API_KEY set successfully!"
        echo ""
        echo "To make this permanent, add this line to your ~/.zshrc or ~/.bash_profile:"
        echo "export GOOGLE_API_KEY=\"$api_key\""
        ;;
    2)
        echo ""
        echo "☁️  Google Cloud Vertex AI Setup"
        echo "==============================="
        read -p "Enter your Google Cloud Project ID: " project_id
        read -p "Enter your Google Cloud location (default: us-central1): " location
        location=${location:-us-central1}
        echo ""
        echo "Setting Google Cloud credentials..."
        export GOOGLE_CLOUD_PROJECT="$project_id"
        export GOOGLE_CLOUD_LOCATION="$location"
        echo "✅ Google Cloud credentials set!"
        echo ""
        echo "To make this permanent, add these lines to your ~/.zshrc or ~/.bash_profile:"
        echo "export GOOGLE_CLOUD_PROJECT=\"$project_id\""
        echo "export GOOGLE_CLOUD_LOCATION=\"$location\""
        ;;
    *)
        echo "❌ Invalid choice. Please run this script again."
        exit 1
        ;;
esac

echo ""
echo "🎉 Authentication configured! You can now run:"
echo "./start_server.sh"
