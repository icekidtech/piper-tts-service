#!/bin/bash

# Piper TTS Service Setup Script
# Run this once to set up the Piper TTS service locally

set -e

echo "🔧 Setting up Piper TTS Service..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Python 3.9+
echo -e "${YELLOW}Checking Python 3.9+...${NC}"
PYTHON_CMD=""
if command -v python3.9 &> /dev/null; then
    PYTHON_CMD="python3.9"
elif command -v python3 &> /dev/null; then
    # Check if it's 3.9+
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    if [[ "$PYTHON_VERSION" == 3.9* ]] || [[ "$PYTHON_VERSION" == 3.1[0-9]* ]]; then
        PYTHON_CMD="python3"
    fi
fi

if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}Error: Python 3.9+ not found${NC}"
    echo "Please install Python 3.9 or later first"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version)
echo -e "${GREEN}✓ Found: $PYTHON_VERSION${NC}"

# Check ffmpeg
echo -e "${YELLOW}Checking FFmpeg...${NC}"
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}Error: FFmpeg not found${NC}"
    echo "Install on macOS: brew install ffmpeg"
    echo "Install on Linux: apt-get install ffmpeg"
    exit 1
fi

FFMPEG_VERSION=$(ffmpeg -version | head -n1)
echo -e "${GREEN}✓ Found: $FFMPEG_VERSION${NC}"

# Create virtual environment
echo -e "${YELLOW}Creating virtual environment...${NC}"
$PYTHON_CMD -m venv venv
source venv/bin/activate

echo -e "${GREEN}✓ Virtual environment created${NC}"

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
pip install --upgrade pip setuptools wheel

# Install requirements
echo -e "${YELLOW}Installing Python dependencies...${NC}"
pip install -r requirements.txt

echo -e "${GREEN}✓ Dependencies installed${NC}"

# Create output directory
echo -e "${YELLOW}Creating output directory...${NC}"
mkdir -p /tmp/piper-audio-output
chmod 777 /tmp/piper-audio-output

echo -e "${GREEN}✓ Output directory created at /tmp/piper-audio-output${NC}"

# Display next steps
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Activate the virtual environment:"
echo "   source venv/bin/activate"
echo ""
echo "2. Run the service:"
echo "   python app.py"
echo ""
echo "3. Test the service:"
echo "   curl http://localhost:5000/health"
echo ""
echo "4. Generate TTS audio:"
echo "   curl -X POST http://localhost:5000/api/tts/generate \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"text\": \"Hello world\", \"language\": \"en-US\", \"voice_gender\": \"male\"}'"
echo ""
