#!/bin/bash

# Run Piper TTS Service locally (development mode)
# This script starts the service and ensures models are available

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Piper TTS Service - Local Setup      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Check if venv exists
if [ ! -d "venv" ]; then
    echo -e "${RED}Error: Virtual environment not found${NC}"
    echo "Run: bash setup.sh"
    exit 1
fi

# Activate venv
source venv/bin/activate
echo -e "${GREEN}✓ Virtual environment activated${NC}"

# Create output directory
mkdir -p /tmp/piper-audio-output
chmod 777 /tmp/piper-audio-output
echo -e "${GREEN}✓ Output directory ready${NC}"

# Setup models directory
PIPER_MODELS_DIR="${PIPER_MODELS_DIR:=~/.local/share/piper}"
PIPER_MODELS_DIR="${PIPER_MODELS_DIR/#\~/$HOME}"

mkdir -p "$PIPER_MODELS_DIR"
echo -e "${GREEN}✓ Models directory: $PIPER_MODELS_DIR${NC}"

# Check and download models if needed
echo ""
echo -e "${YELLOW}📦 Checking Piper TTS Models...${NC}"

# Array of essential models to check
declare -a MODELS=(
    "en_US-male-medium"
    "en_US-female-medium"
)

MODEL_COUNT=0
MISSING_MODELS=0

for MODEL in "${MODELS[@]}"; do
    MODEL_FILE="$PIPER_MODELS_DIR/${MODEL}.onnx"
    CONFIG_FILE="$PIPER_MODELS_DIR/${MODEL}.onnx.json"
    
    if [ -f "$MODEL_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓${NC} $MODEL"
        ((MODEL_COUNT++))
    else
        echo -e "${YELLOW}✗${NC} $MODEL (missing)"
        ((MISSING_MODELS++))
    fi
done

# If models are missing, offer to download
if [ $MISSING_MODELS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Missing $MISSING_MODELS model(s)${NC}"
    echo ""
    echo -e "${YELLOW}Would you like to download missing models? (y/n)${NC}"
    read -r -t 10 -p "Auto-proceeding in 10 seconds... " response || response="y"
    
    if [[ "$response" =~ ^[Yy]$ ]] || [ -z "$response" ]; then
        echo ""
        echo -e "${BLUE}Downloading Piper TTS models...${NC}"
        
        for MODEL in "${MODELS[@]}"; do
            MODEL_FILE="$PIPER_MODELS_DIR/${MODEL}.onnx"
            CONFIG_FILE="$PIPER_MODELS_DIR/${MODEL}.onnx.json"
            
            if [ ! -f "$MODEL_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
                echo -e "${YELLOW}Downloading: $MODEL${NC}"
                
                # Parse model name to get language/country/gender/quality
                IFS='_' read -r LANG REGION GENDER QUALITY <<< "$MODEL"
                REGION_CODE="${REGION:0:2}"
                
                # Build HuggingFace URL
                HF_BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main"
                HF_URL="${HF_BASE}/${LANG}/${LANG}_${REGION}/${GENDER}/${QUALITY}/${MODEL}"
                
                # Download model file
                echo -e "  ${BLUE}→${NC} Downloading ${MODEL}.onnx..."
                wget -q -O "$MODEL_FILE" "${HF_URL}.onnx" || {
                    echo -e "${RED}  ✗ Failed to download ${MODEL}.onnx${NC}"
                    continue
                }
                echo -e "${GREEN}  ✓ Downloaded${NC}"
                
                # Download config file
                echo -e "  ${BLUE}→${NC} Downloading ${MODEL}.onnx.json..."
                wget -q -O "$CONFIG_FILE" "${HF_URL}.onnx.json" || {
                    echo -e "${RED}  ✗ Failed to download ${MODEL}.onnx.json${NC}"
                    continue
                }
                echo -e "${GREEN}  ✓ Downloaded${NC}"
            fi
        done
        
        echo ""
        MODEL_COUNT=$(ls "$PIPER_MODELS_DIR"/*.onnx 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ Models ready: $MODEL_COUNT model(s) available${NC}"
    fi
fi

# Final model check
echo ""
echo -e "${BLUE}Available Models:${NC}"
ls "$PIPER_MODELS_DIR"/*.onnx 2>/dev/null | xargs -I {} basename {} .onnx | while read MODEL; do
    echo -e "  ${GREEN}•${NC} $MODEL"
done

# Export environment variables
export PIPER_MODELS_DIR="$PIPER_MODELS_DIR"
export PIPER_OUTPUT_DIR=/tmp/piper-audio-output
export FLASK_ENV=development

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Configuration Ready                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "   Service: Piper TTS Microservice"
echo "   Host: http://localhost:5000"
echo "   Models Dir: $PIPER_MODELS_DIR"
echo "   Output Dir: /tmp/piper-audio-output"
echo "   Environment: development"
echo ""
echo -e "${YELLOW}📡 Available Endpoints:${NC}"
echo "   GET  /health                      - Health check & available voices"
echo "   GET  /api/voices                  - List all available voices"
echo "   POST /api/tts/generate            - Generate TTS audio"
echo "   GET  /api/audio/<audio_id>        - Download audio"
echo "   GET  /api/stats                   - Service statistics"
echo ""
echo -e "${YELLOW}🧪 Test Examples:${NC}"
echo ""
echo "1. Health Check:"
echo "   curl http://localhost:5000/health"
echo ""
echo "2. List Available Voices:"
echo "   curl http://localhost:5000/api/voices | jq"
echo ""
echo "3. Generate TTS (Male):"
echo "   curl -X POST http://localhost:5000/api/tts/generate \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"text\": \"Hello world\", \"voice\": \"en-US-male-medium\"}'"
echo ""
echo "4. Generate TTS (Female):"
echo "   curl -X POST http://localhost:5000/api/tts/generate \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"text\": \"Hello world\", \"voice\": \"en-US-female-medium\"}'"
echo ""
echo "5. Download Audio:"
echo "   curl http://localhost:5000/api/audio/YOUR_AUDIO_ID -o audio.wav"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Run the app
python app.py
