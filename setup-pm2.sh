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

# Ensure venv exists
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating Python virtual environment...${NC}"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    echo -e "${GREEN}✓ Virtual environment created${NC}"
else
    echo -e "${GREEN}✓ Virtual environment already exists${NC}"
fi

echo ""

# Start with PM2
echo -e "${YELLOW}Starting Piper TTS with PM2...${NC}"
pm2 start ecosystem.config.js
echo -e "${GREEN}✓ Piper TTS started with PM2${NC}"

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
