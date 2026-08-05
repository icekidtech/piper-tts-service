# Piper TTS Voice System Guide

## Overview

The Piper TTS service now supports **30+ voices** across multiple languages with flexible configuration. The service allows the frontend (or any client) to select specific voices dynamically, rather than being hardcoded to a single model.

## Supported Voices

### English (United States)
- `en-US-male-low` - Male, low quality
- `en-US-male-medium` - Male, medium quality (recommended)
- `en-US-male-high` - Male, high quality
- `en-US-female-low` - Female, low quality
- `en-US-female-medium` - Female, medium quality
- `en-US-female-high` - Female, high quality

### English (British)
- `en-GB-male-medium` - Male, medium quality
- `en-GB-female-medium` - Female, medium quality

### Spanish
- `es-ES-male-medium` - Spanish (Spain)
- `es-ES-female-medium` - Spanish (Spain)
- `es-MX-male-medium` - Spanish (Mexico)

### French
- `fr-FR-male-medium` - Male
- `fr-FR-female-medium` - Female

### German
- `de-DE-male-medium` - Male
- `de-DE-female-medium` - Female

### Italian
- `it-IT-male-medium` - Male
- `it-IT-female-medium` - Female

### Portuguese
- `pt-BR-male-medium` - Portuguese (Brazil)
- `pt-BR-female-medium` - Portuguese (Brazil)
- `pt-PT-male-medium` - Portuguese (Portugal)

### Dutch
- `nl-NL-male-medium` - Male
- `nl-NL-female-medium` - Female

### Russian
- `ru-RU-male-medium` - Male
- `ru-RU-female-medium` - Female

### Polish
- `pl-PL-male-medium` - Male
- `pl-PL-female-medium` - Female

---

## Setup for Development (Localhost)

### Download Models You Want

Models are stored in `~/.local/share/piper/` on your local machine.

```bash
# Create directory
mkdir -p ~/.local/share/piper
cd ~/.local/share/piper

# Download English US Male Medium (recommended starting point)
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/male/medium/en_US-male-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/male/medium/en_US-male-medium.onnx.json

# Download English US Female (optional)
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/female/medium/en_US-female-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/female/medium/en_US-female-medium.onnx.json

# Download any other voices you want...
```

### Check Available Models

When you run the service, it will show you which models are available:

```bash
bash run.sh
```

The output will show:
```
✓ Found 2 model(s) in /Users/icekid/.local/share/piper
```

You can also query the `/health` endpoint:

```bash
curl http://localhost:5000/health | jq '.voices_available'
```

Response:
```json
["en-US-male-medium", "en-US-female-medium"]
```

---

## Frontend Usage (NEW)

### 1. Get Available Voices

```bash
curl http://localhost:5000/api/voices
```

Response shows which voices are available and their details:

```json
{
  "available_voices": {
    "en-US-male-medium": {
      "available": true,
      "language": "English (US)",
      "gender": "male",
      "quality": "medium"
    },
    "es-ES-male-medium": {
      "available": true,
      "language": "Spanish (ES)",
      "gender": "male",
      "quality": "medium"
    }
  },
  "default_voice": "en-US-male-medium",
  "total_configured": 30,
  "total_available": 2
}
```

### 2. Generate Audio with Specific Voice

**Frontend sends:**
```json
{
  "text": "Hello, how are you?",
  "voice": "en-US-male-medium"
}
```

**Request:**
```bash
curl -X POST http://localhost:5000/api/tts/generate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, how are you?",
    "voice": "en-US-male-medium"
  }'
```

**Response:**
```json
{
  "audio_id": "550e8400-e29b-41d4-a716-446655440000",
  "duration": 3,
  "file_size": 9600,
  "voice": "en-US-male-medium",
  "local_url": "http://localhost:5000/api/audio/550e8400-e29b-41d4-a716-446655440000",
  "status": "ready"
}
```

---

## Backend Integration (Go)

In your Go backend (`gramvoicebackend`), you would call the Piper service:

```go
import (
    "bytes"
    "encoding/json"
    "net/http"
)

// Call Piper service with voice selection
requestBody := map[string]interface{}{
    "text": userText,
    "voice": "en-US-male-medium", // Frontend or backend specifies voice
}

jsonBody, _ := json.Marshal(requestBody)

resp, _ := http.Post(
    "http://localhost:5000/api/tts/generate",
    "application/json",
    bytes.NewBuffer(jsonBody),
)

// Parse response
var result struct {
    AudioID  string `json:"audio_id"`
    Duration int    `json:"duration"`
    Voice    string `json:"voice"`
    LocalURL string `json:"local_url"`
}
json.NewDecoder(resp.Body).Decode(&result)
```

---

## Adding New Voices

To add a new voice:

1. **Download the model files:**
   ```bash
   cd ~/.local/share/piper
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/[LANGUAGE]/[COUNTRY]/[GENDER]/[QUALITY]/[VOICE_NAME].onnx
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/[LANGUAGE]/[COUNTRY]/[GENDER]/[QUALITY]/[VOICE_NAME].onnx.json
   ```

2. **The service will automatically detect it!**
   - Just restart the service
   - Check `/api/voices` - new voice will appear
   - Use it with `"voice": "language-COUNTRY-gender-quality"`

No code changes needed!

---

## File Structure

```
piper-tts-service/
├── app.py                    # Main Flask app with voice support
├── run.sh                    # Start script (checks ~/.local/share/piper)
├── requirements.txt          # Python dependencies
├── .env.example             # Environment variables
└── README.md                # Full documentation
```

## Environment Variables

### Development (Localhost)
```bash
PIPER_MODELS_DIR=~/.local/share/piper    # Expands to home directory
PIPER_OUTPUT_DIR=/tmp/piper-audio-output
```

### Production (VPS)
```bash
PIPER_MODELS_DIR=/opt/piper-models
PIPER_OUTPUT_DIR=/var/lib/piper/audio-output
```

---

## API Responses

### Success: Voice Available
```json
{
  "status": "healthy",
  "voices_available": ["en-US-male-medium", "es-ES-male-medium"],
  "total_voices_configured": 30,
  "total_available": 2
}
```

### Error: Voice Not Downloaded
```json
{
  "error": "Model files not found for voice: en-US-male-medium",
  "expected_model": "/Users/icekid/.local/share/piper/en_US-male-medium.onnx"
}
```

Solution: Download the model files as shown in setup section.

### Error: Unknown Voice ID
```json
{
  "error": "Unknown voice: invalid-voice",
  "available_voices": ["en-US-male-medium", "en-US-female-medium"]
}
```

Solution: Use one of the available voices from the list.

---

## Summary

✅ **No more hardcoding!** - Frontend specifies voice  
✅ **30+ voices supported** - English, Spanish, French, German, Italian, Portuguese, Dutch, Russian, Polish  
✅ **Flexible setup** - Download only voices you need  
✅ **Easy to add** - New voices detected automatically  
✅ **Backward compatible** - Old language+gender format still works  
✅ **Production ready** - Works on VPS with different model paths  

Frontend dev now has full control over which voice to use! 🎙️
