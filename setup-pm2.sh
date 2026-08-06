#!/bin/bash

# PM2 Setup for Piper TTS Service
# Run this script to configure PM2 to manage the Piper TTS service

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   PM2 Setup for Piper TTS Service     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if PM2 is installed
if ! command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}PM2 not found. Installing...${NC}"
    npm install -g pm2
    echo -e "${GREEN}✓ PM2 installed${NC}"
else
    echo -e "${GREEN}✓ PM2 already installed${NC}"
fi

echo ""

# Create log directory
echo -e "${YELLOW}Setting up log directory...${NC}"
sudo mkdir -p /var/log/pm2
sudo chown $(whoami):$(whoami) /var/log/pm2
echo -e "${GREEN}✓ Log directory ready: /var/log/pm2${NC}"

echo ""

# Ensure venv exists and activate it
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating Python virtual environment...${NC}"
    python3 -m venv venv
fi

echo -e "${YELLOW}Activating virtual environment...${NC}"
source venv/bin/activate

# Upgrade pip and install requirements
echo -e "${YELLOW}Installing/updating Python dependencies...${NC}"
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
echo -e "${GREEN}✓ Python dependencies installed${NC}"

# Verify piper is installed
echo -e "${YELLOW}Verifying Piper installation...${NC}"
python3 -c "import piper; print('✓ Piper installed')" || {
    echo -e "${RED}✗ Piper not found in venv!${NC}"
    exit 1
}
echo -e "${GREEN}✓ Piper verified${NC}"

echo ""

# Check models directory
MODELS_DIR="/home/hustleloop-admin/.local/share/piper"
if [ ! -d "$MODELS_DIR" ]; then
    echo -e "${YELLOW}⚠️  Piper models directory not found at $MODELS_DIR${NC}"
    echo -e "${YELLOW}Please run ./download-voices.sh to download models${NC}"
else
    VOICE_COUNT=$(ls "$MODELS_DIR"/*.onnx 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ Found $VOICE_COUNT voice models in $MODELS_DIR${NC}"
fi

echo ""

# Stop existing PM2 process if running (first time setup)
if pm2 list | grep -q "piper-tts"; then
    echo -e "${YELLOW}Reloading existing piper-tts process (zero-downtime)...${NC}"
    pm2 reload ecosystem.config.js
    echo -e "${GREEN}✓ Piper TTS reloaded with PM2${NC}"
else
    echo -e "${YELLOW}Starting Piper TTS with PM2...${NC}"
    pm2 start ecosystem.config.js
    echo -e "${GREEN}✓ Piper TTS started with PM2${NC}"
fi

echo ""

# Save PM2 process list
echo -e "${YELLOW}Saving PM2 process list...${NC}"
pm2 save
echo -e "${GREEN}✓ PM2 process list saved${NC}"

echo ""

# Setup PM2 auto-startup on reboot
echo -e "${YELLOW}Setting up PM2 auto-startup...${NC}"
pm2 startup systemd -u $(whoami) --hp /home/$(whoami)
echo -e "${GREEN}✓ PM2 auto-startup configured${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Setup Complete!                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

echo "Next steps:"
echo ""
echo "1. View logs:"
echo "   pm2 logs piper-tts"
echo ""
echo "2. Check status:"
echo "   pm2 status"
echo ""
echo "3. Monitor in real-time:"
echo "   pm2 monit"
echo ""
echo "4. Restart service:"
echo "   pm2 restart piper-tts"
echo ""
echo "5. Stop service:"
echo "   pm2 stop piper-tts"
echo ""
echo "6. View all PM2 commands:"
echo "   pm2 help"
echo ""

# Show current status
echo -e "${BLUE}Current Status:${NC}"
pm2 status
echo ""
pm2 logs piper-tts --lines 10
