#!/bin/bash

# Download Piper TTS voice models
# This script allows you to download specific voice models

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PIPER_MODELS_DIR="${PIPER_MODELS_DIR:=~/.local/share/piper}"
PIPER_MODELS_DIR="${PIPER_MODELS_DIR/#\~/$HOME}"

mkdir -p "$PIPER_MODELS_DIR"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Piper TTS Voice Model Downloader     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Models will be saved to: $PIPER_MODELS_DIR"
echo ""

# Function to download a model
download_model() {
    local MODEL_NAME=$1
    local HF_PATH=$2
    
    local MODEL_FILE="$PIPER_MODELS_DIR/${MODEL_NAME}.onnx"
    local CONFIG_FILE="$PIPER_MODELS_DIR/${MODEL_NAME}.onnx.json"
    
    if [ -f "$MODEL_FILE" ] && [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓${NC} $MODEL_NAME (already exists)"
        return 0
    fi
    
    echo -e "${YELLOW}Downloading: $MODEL_NAME${NC}"
    
    # Download model
    echo -e "  ${BLUE}→${NC} .onnx file..."
    if wget -q -O "$MODEL_FILE" "https://huggingface.co/rhasspy/piper-voices/resolve/main/${HF_PATH}/${MODEL_NAME}.onnx"; then
        echo -e "    ${GREEN}✓${NC} Done"
    else
        echo -e "    ${RED}✗${NC} Failed"
        rm -f "$MODEL_FILE"
        return 1
    fi
    
    # Download config
    echo -e "  ${BLUE}→${NC} .onnx.json file..."
    if wget -q -O "$CONFIG_FILE" "https://huggingface.co/rhasspy/piper-voices/resolve/main/${HF_PATH}/${MODEL_NAME}.onnx.json"; then
        echo -e "    ${GREEN}✓${NC} Done"
    else
        echo -e "    ${RED}✗${NC} Failed"
        rm -f "$CONFIG_FILE"
        return 1
    fi
}

# Available voices
declare -A VOICES=(
    # English US
    ["en-US Male Medium"]="en_US-male-medium:en/en_US/male/medium"
    ["en-US Male High"]="en_US-male-high:en/en_US/male/high"
    ["en-US Male Low"]="en_US-male-low:en/en_US/male/low"
    ["en-US Female Medium"]="en_US-female-medium:en/en_US/female/medium"
    ["en-US Female High"]="en_US-female-high:en/en_US/female/high"
    ["en-US Female Low"]="en_US-female-low:en/en_US/female/low"
    
    # English UK
    ["en-GB Male Medium"]="en_GB-male-medium:en/en_GB/male/medium"
    ["en-GB Female Medium"]="en_GB-female-medium:en/en_GB/female/medium"
    
    # Spanish
    ["Spanish (Spain) Male"]="es_ES-male-medium:es/es_ES/male/medium"
    ["Spanish (Spain) Female"]="es_ES-female-medium:es/es_ES/female/medium"
    ["Spanish (Mexico) Male"]="es_MX-male-medium:es/es_MX/male/medium"
    
    # French
    ["French Male"]="fr_FR-male-medium:fr/fr_FR/male/medium"
    ["French Female"]="fr_FR-female-medium:fr/fr_FR/female/medium"
    
    # German
    ["German Male"]="de_DE-male-medium:de/de_DE/male/medium"
    ["German Female"]="de_DE-female-medium:de/de_DE/female/medium"
    
    # Italian
    ["Italian Male"]="it_IT-male-medium:it/it_IT/male/medium"
    ["Italian Female"]="it_IT-female-medium:it/it_IT/female/medium"
    
    # Portuguese
    ["Portuguese (Brazil) Male"]="pt_BR-male-medium:pt/pt_BR/male/medium"
    ["Portuguese (Brazil) Female"]="pt_BR-female-medium:pt/pt_BR/female/medium"
    ["Portuguese (Portugal) Male"]="pt_PT-male-medium:pt/pt_PT/male/medium"
    
    # Dutch
    ["Dutch Male"]="nl_NL-male-medium:nl/nl_NL/male/medium"
    ["Dutch Female"]="nl_NL-female-medium:nl/nl_NL/female/medium"
    
    # Russian
    ["Russian Male"]="ru_RU-male-medium:ru/ru_RU/male/medium"
    ["Russian Female"]="ru_RU-female-medium:ru/ru_RU/female/medium"
    
    # Polish
    ["Polish Male"]="pl_PL-male-medium:pl/pl_PL/male/medium"
    ["Polish Female"]="pl_PL-female-medium:pl/pl_PL/female/medium"
)

# Display options
echo -e "${BLUE}Available Voices:${NC}"
echo ""

i=1
declare -a SORTED_KEYS
for key in "${!VOICES[@]}"; do
    SORTED_KEYS+=("$key")
done

# Sort array
IFS=$'\n' SORTED_KEYS=($(sort <<<"${SORTED_KEYS[*]}"))
unset IFS

for key in "${SORTED_KEYS[@]}"; do
    echo "  $i. $key"
    ((i++))
done

echo ""
echo "  a. Download RECOMMENDED voices (Male + Female US English)"
echo "  b. Download ALL voices"
echo "  q. Quit"
echo ""
read -p "Select voices to download: " choice

case $choice in
    a)
        echo ""
        echo -e "${YELLOW}Downloading recommended voices...${NC}"
        echo ""
        download_model "en_US-male-medium" "en/en_US/male/medium"
        download_model "en_US-female-medium" "en/en_US/female/medium"
        ;;
    b)
        echo ""
        echo -e "${YELLOW}Downloading all voices (this will take 10-15 minutes)...${NC}"
        echo -e "${YELLOW}Total size: ~2.5GB${NC}"
        echo ""
        
        TOTAL=${#SORTED_KEYS[@]}
        CURRENT=0
        FAILED=0
        
        for key in "${SORTED_KEYS[@]}"; do
            ((CURRENT++))
            echo -e "${BLUE}[$CURRENT/$TOTAL]${NC} Downloading: $key"
            IFS=':' read -r MODEL_NAME HF_PATH <<< "${VOICES[$key]}"
            
            if ! download_model "$MODEL_NAME" "$HF_PATH"; then
                ((FAILED++))
            fi
        done
        
        echo ""
        if [ $FAILED -eq 0 ]; then
            echo -e "${GREEN}All voices downloaded successfully!${NC}"
        else
            echo -e "${YELLOW}Downloaded with $FAILED failures${NC}"
        fi
        ;;
    q)
        echo "Exiting..."
        exit 0
        ;;
    *)
        # Handle numeric choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le ${#SORTED_KEYS[@]} ]; then
            idx=$((choice - 1))
            key="${SORTED_KEYS[$idx]}"
            IFS=':' read -r MODEL_NAME HF_PATH <<< "${VOICES[$key]}"
            echo ""
            download_model "$MODEL_NAME" "$HF_PATH"
        else
            echo -e "${RED}Invalid choice${NC}"
            exit 1
        fi
        ;;
esac

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Complete!                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Available models in $PIPER_MODELS_DIR:"
ls "$PIPER_MODELS_DIR"/*.onnx 2>/dev/null | xargs -I {} basename {} .onnx | while read MODEL; do
    echo -e "  ${GREEN}•${NC} $MODEL"
done
echo ""
echo "To start the service, run: bash run.sh"
echo ""
