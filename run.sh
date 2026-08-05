#!/bin/bash

# Run Piper TTS Service locally (development mode)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}🚀 Starting Piper TTS Service...${NC}"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo -e "${RED}Error: Virtual environment not found${NC}"
    echo "Run: bash setup.sh"
    exit 1
fi

# Activate venv
source venv/bin/activate

echo -e "${GREEN}✓ Virtual environment activated${NC}"

# Create output directory if it doesn't exist
mkdir -p /tmp/piper-audio-output
chmod 777 /tmp/piper-audio-output

echo -e "${GREEN}✓ Output directory ready${NC}"

# Export environment variables for development
export PIPER_OUTPUT_DIR=/tmp/piper-audio-output
export FLASK_ENV=development

echo ""
echo -e "${GREEN}✅ Configuration:${NC}"
echo "   Service: Piper TTS Microservice"
echo "   Host: http://localhost:5000"
echo "   Output Dir: /tmp/piper-audio-output"
echo "   Environment: development"
echo ""
echo -e "${YELLOW}📡 Available Endpoints:${NC}"
echo "   GET  /health                      - Health check"
echo "   POST /api/tts/generate            - Generate TTS audio"
echo "   GET  /api/audio/<audio_id>        - Download audio"
echo "   GET  /api/stats                   - Service statistics"
echo ""
echo -e "${YELLOW}🧪 Test Examples:${NC}"
echo ""
echo "1. Health Check:"
echo "   curl http://localhost:5000/health"
echo ""
echo "2. Generate TTS:"
echo "   curl -X POST http://localhost:5000/api/tts/generate \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"text\": \"Hello world\", \"language\": \"en-US\", \"voice_gender\": \"male\"}'"
echo ""
echo "3. Download Audio (copy audio_id from generate response):"
echo "   curl http://localhost:5000/api/audio/YOUR_AUDIO_ID -o audio.wav"
echo ""
echo "4. Service Stats:"
echo "   curl http://localhost:5000/api/stats"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Run the app
python app.py
