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

# Voice models to check (VOICE_ID MODEL_NAME pairs)
VOICE_CONFIGS="en-US-male-medium:en_US-ryan-medium en-US-female-medium:en_US-amy-medium"

MODEL_COUNT=0
MISSING_MODELS=0
MISSING_VOICE_MODELS=""

# Check which models exist
for VOICE_CONFIG in $VOICE_CONFIGS; do
    VOICE_ID="${VOICE_CONFIG%:*}"
    MODEL_NAME="${VOICE_CONFIG#*:}"
    MODEL_FILE="$PIPER_MODELS_DIR/${MODEL_NAME}.onnx"
    CONFIG_FILE="$PIPER_MODELS_DIR/${MODEL_NAME}.onnx.json"
    
    if [ -f "$MODEL_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        SIZE=$(ls -lh "$MODEL_FILE" | awk '{print $5}')
        echo -e "${GREEN}✓${NC} $VOICE_ID ($SIZE)"
        MODEL_COUNT=$((MODEL_COUNT + 1))
    else
        echo -e "${RED}✗${NC} $VOICE_ID (missing)"
        MISSING_VOICE_MODELS="$MISSING_VOICE_MODELS $VOICE_CONFIG"
        MISSING_MODELS=$((MISSING_MODELS + 1))
    fi
done

# If models are missing, offer to download
if [ $MISSING_MODELS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Missing $MISSING_MODELS voice model(s)${NC}"
    echo ""
    
    # Use timeout for 5 seconds (macOS compatible)
    echo -e "${YELLOW}Download missing models? (y/n) [auto-yes in 5s]${NC}"
    
    # Read with 5 second timeout
    response="y"
    timeout 5s bash -c 'read -r response; echo "$response"' > /tmp/response.txt 2>/dev/null || response="y"
    
    if [ -f /tmp/response.txt ]; then
        response=$(cat /tmp/response.txt | tr -d '\n')
    fi
    
    if [ "$response" = "y" ] || [ "$response" = "Y" ] || [ -z "$response" ]; then
        echo ""
        echo -e "${BLUE}Downloading Piper TTS models...${NC}"
        
        for VOICE_CONFIG in $MISSING_VOICE_MODELS; do
            VOICE_ID="${VOICE_CONFIG%:*}"
            MODEL_NAME="${VOICE_CONFIG#*:}"
            
            MODEL_FILE="$PIPER_MODELS_DIR/${MODEL_NAME}.onnx"
            CONFIG_FILE="$PIPER_MODELS_DIR/${MODEL_NAME}.onnx.json"
            
            # Parse model name: en_US-ryan-medium -> en_US, ryan, medium
            LANG_COUNTRY=$(echo "$MODEL_NAME" | cut -d'-' -f1-2)
            SPEAKER=$(echo "$MODEL_NAME" | cut -d'-' -f3)
            QUALITY=$(echo "$MODEL_NAME" | cut -d'-' -f4)
            
            # Build HuggingFace URL
            HF_BASE="https://huggingface.co/rhasspy/piper-voices/resolve/main"
            HF_URL="${HF_BASE}/en/${LANG_COUNTRY}/${SPEAKER}/${QUALITY}/${MODEL_NAME}"
            
            echo -e "${YELLOW}Downloading: $VOICE_ID${NC}"
            
            # Download model file using curl (macOS compatible)
            echo -e "  ${BLUE}→${NC} Downloading ${MODEL_NAME}.onnx..."
            if curl -L -f -o "$MODEL_FILE" "${HF_URL}.onnx" 2>/dev/null; then
                SIZE=$(ls -lh "$MODEL_FILE" | awk '{print $5}')
                echo -e "  ${GREEN}✓ Downloaded ($SIZE)${NC}"
            else
                echo -e "  ${RED}✗ Failed to download${NC}"
                rm -f "$MODEL_FILE"
                continue
            fi
            
            # Download config file
            echo -e "  ${BLUE}→${NC} Downloading ${MODEL_NAME}.onnx.json..."
            if curl -L -f -o "$CONFIG_FILE" "${HF_URL}.onnx.json" 2>/dev/null; then
                echo -e "  ${GREEN}✓ Downloaded${NC}"
            else
                echo -e "  ${RED}✗ Failed to download config${NC}"
                rm -f "$CONFIG_FILE"
                rm -f "$MODEL_FILE"
                continue
            fi
        done
        
        echo ""
        MODEL_COUNT=$(ls "$PIPER_MODELS_DIR"/*.onnx 2>/dev/null | wc -l)
        echo -e "${GREEN}✓ Models ready: $MODEL_COUNT voice model(s) available${NC}"
    else
        echo -e "${RED}Download cancelled. Models required to run service.${NC}"
        exit 1
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
