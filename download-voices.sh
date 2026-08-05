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
    
    # Download model (with progress bar)
    echo -e "  ${BLUE}→${NC} .onnx file..."
    if wget --show-progress -O "$MODEL_FILE" "https://huggingface.co/rhasspy/piper-voices/resolve/main/${HF_PATH}/${MODEL_NAME}.onnx" 2>&1; then
        SIZE=$(ls -lh "$MODEL_FILE" | awk '{print $5}')
        echo -e "    ${GREEN}✓${NC} Done ($SIZE)"
    else
        echo -e "    ${RED}✗${NC} Failed"
        rm -f "$MODEL_FILE"
        return 1
    fi
    
    # Download config (with progress bar)
    echo -e "  ${BLUE}→${NC} .onnx.json file..."
    if wget --show-progress -O "$CONFIG_FILE" "https://huggingface.co/rhasspy/piper-voices/resolve/main/${HF_PATH}/${MODEL_NAME}.onnx.json" 2>&1; then
        echo -e "    ${GREEN}✓${NC} Done"
    else
        echo -e "    ${RED}✗${NC} Failed"
        rm -f "$CONFIG_FILE"
        return 1
    fi
}

# Available voices (speaker-based, not gender/quality based)
declare -A VOICES=(
    # English US (Speakers: ryan=male, amy=female, etc.)
    ["en-US Ryan (Male, Medium)"]="en_US-ryan-medium:en/en_US/ryan/medium"
    ["en-US Amy (Female, Medium)"]="en_US-amy-medium:en/en_US/amy/medium"
    ["en-US Danny (Male, Medium)"]="en_US-danny-medium:en/en_US/danny/medium"
    ["en-US Kathleen (Female, Medium)"]="en_US-kathleen-medium:en/en_US/kathleen/medium"
    ["en-US Kristin (Female, Medium)"]="en_US-kristin-medium:en/en_US/kristin/medium"
    ["en-US Kusal (Male, Medium)"]="en_US-kusal-medium:en/en_US/kusal/medium"
    ["en-US Joe (Male, Medium)"]="en_US-joe-medium:en/en_US/joe/medium"
    ["en-US Lessac (Male, Medium)"]="en_US-lessac-medium:en/en_US/lessac/medium"
    
    # English GB
    ["en-GB Alan (Male, Medium)"]="en_GB-alan-medium:en/en_GB/alan/medium"
    ["en-GB Jon (Male, Medium)"]="en_GB-jon-medium:en/en_GB/jon/medium"
    
    # Spanish
    ["es-ES Alberto (Male, Medium)"]="es_ES-alberto-medium:es/es_ES/alberto/medium"
    ["es-ES Carla (Female, Medium)"]="es_ES-carla-medium:es/es_ES/carla/medium"
    ["es-MX Juan (Male, Medium)"]="es_MX-juan-medium:es/es_MX/juan/medium"
    
    # French
    ["fr-FR Siwis (Female, Medium)"]="fr_FR-siwis-medium:fr/fr_FR/siwis/medium"
    
    # German
    ["de-DE Thorsten (Male, Medium)"]="de_DE-thorsten-medium:de/de_DE/thorsten/medium"
    
    # Italian
    ["it-IT Riccardo (Male, Medium)"]="it_IT-riccardo-medium:it/it_IT/riccardo/medium"
    
    # Portuguese
    ["pt-BR Antonio (Male, Medium)"]="pt_BR-antonio-medium:pt/pt_BR/antonio/medium"
    ["pt-PT Mariana (Female, Medium)"]="pt_PT-mariana-medium:pt/pt_PT/mariana/medium"
    
    # Dutch
    ["nl-NL Frank (Male, Medium)"]="nl_NL-frank-medium:nl/nl_NL/frank/medium"
    ["nl-NL Flemish (Female, Medium)"]="nl_NL-flemish-medium:nl/nl_NL/flemish/medium"
    
    # Russian
    ["ru-RU Dmitri (Male, Medium)"]="ru_RU-dmitri-medium:ru/ru_RU/dmitri/medium"
    
    # Polish
    ["pl-PL Zuzanna (Female, Medium)"]="pl_PL-zuzanna-medium:pl/pl_PL/zuzanna/medium"
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
        download_model "en_US-ryan-medium" "en/en_US/ryan/medium"
        download_model "en_US-amy-medium" "en/en_US/amy/medium"
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
            PERCENT=$((CURRENT * 100 / TOTAL))
            echo -e "${BLUE}[$PERCENT%]${NC} [$CURRENT/$TOTAL] Downloading: $key"
            IFS=':' read -r MODEL_NAME HF_PATH <<< "${VOICES[$key]}"
            
            if ! download_model "$MODEL_NAME" "$HF_PATH"; then
                ((FAILED++))
            fi
            echo ""
        done
        
        echo ""
        if [ $FAILED -eq 0 ]; then
            echo -e "${GREEN}✓ All voices downloaded successfully!${NC}"
        else
            echo -e "${YELLOW}⚠ Downloaded with $FAILED failures${NC}"
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
