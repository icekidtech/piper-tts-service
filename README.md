# Piper TTS Microservice

A lightweight microservice for Text-to-Speech audio generation using Piper TTS. Designed to be deployed separately from the main backend and integrate via HTTP API.

## Features

- 🎙️ **TTS Generation**: Convert text to speech using Piper TTS
- 🔄 **Audio Codec Conversion**: Automatic WAV → ULAW conversion (Twilio compatible)
- 🌐 **REST API**: Simple HTTP endpoints for integration
- 📊 **Health Checks**: Built-in service monitoring
- 🔒 **CORS Enabled**: Safe cross-origin requests
- 📝 **Comprehensive Logging**: Detailed operation tracking
- ⚡ **Async File Operations**: Non-blocking audio generation
- 🧹 **Configurable Output**: Customizable audio storage location

## Architecture

```
┌─────────────────────────────────┐
│  Backend (Go)                   │
│  /api/campaigns/upload-audio    │
└────────────┬────────────────────┘
             │ HTTP POST
             ▼
┌─────────────────────────────────┐
│  Piper TTS Service (Python)     │
│  Flask Microservice             │
│  Port 5000                      │
└────────────┬────────────────────┘
             │
      ┌──────┴──────┐
      ▼             ▼
   Piper TTS    FFmpeg
   (Generate)   (Convert)
      │             │
      └──────┬──────┘
             ▼
      Audio Output
      /tmp/piper-audio-output/
```

## Requirements

- Python 3.9+
- FFmpeg (for audio conversion)
- 2GB+ RAM (for Piper models)
- Network access (for downloading models on first run)

## Installation

### 1. Clone or Download

```bash
# If moving from main repo
cp -r piper-tts-service/ /path/to/new/location
cd piper-tts-service
```

### 2. Run Setup

```bash
bash setup.sh
```

This will:
- Verify Python 3.9 and FFmpeg are installed
- Create virtual environment
- Install dependencies
- Create output directory

### 3. Download Piper Models

Piper models need to be downloaded once. The models are downloaded to `/opt/piper-models/`:

```bash
# Models will be auto-downloaded on first use, or manually:
mkdir -p /opt/piper-models
cd /opt/piper-models

# Download English US Male Medium model
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/male/medium/en_US-male-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/male/medium/en_US-male-medium.onnx.json
```

## Running

### Local Development

```bash
bash run.sh
```

This starts the Flask development server on `http://localhost:5000`

### Production with Systemd

```bash
# Copy service file
sudo cp piper-tts.service /etc/systemd/system/

# Create piper user
sudo useradd -r -s /bin/bash piper

# Set up directories
sudo mkdir -p /opt/piper-service /opt/piper-models /var/lib/piper/audio-output
sudo chown -R piper:piper /opt/piper-service /opt/piper-models /var/lib/piper

# Copy app to /opt/piper-service
sudo cp -r . /opt/piper-service/
sudo chown -R piper:piper /opt/piper-service

# Start service
sudo systemctl daemon-reload
sudo systemctl start piper-tts
sudo systemctl enable piper-tts
sudo systemctl status piper-tts

# View logs
sudo journalctl -u piper-tts -f
```

### Production with Docker (Optional)

Create `Dockerfile`:

```dockerfile
FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

ENV PIPER_MODEL_PATH=/models/en_US-male-medium.onnx
ENV PIPER_CONFIG_PATH=/models/en_US-male-medium.onnx.json
ENV PIPER_OUTPUT_DIR=/audio-output

VOLUME ["/models", "/audio-output"]

EXPOSE 5000

CMD ["python", "app.py"]
```

Build and run:

```bash
docker build -t piper-tts .
docker run -d -p 5000:5000 \
  -v /opt/piper-models:/models \
  -v /var/lib/piper/audio-output:/audio-output \
  piper-tts
```

## API Endpoints

### 1. Health Check

**Endpoint:** `GET /health`

Check service health and model availability.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "service": "piper-tts",
  "version": "1.0.0",
  "model_path": "/opt/piper-models/en_US-male-medium.onnx",
  "timestamp": "2026-08-05T15:30:00.000000"
}
```

**Response (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "error": "Model files not found",
  "model_exists": false,
  "config_exists": false
}
```

---

### 2. Generate TTS Audio

**Endpoint:** `POST /api/tts/generate`

Generate TTS audio from text.

**Request:**
```json
{
  "text": "Hello, this is a test message",
  "language": "en-US",
  "voice_gender": "male"
}
```

**Parameters:**
- `text` (required): Text to convert to speech (max 500 chars)
- `language` (optional, default: "en-US"): Language code
- `voice_gender` (optional, default: "male"): Voice gender ("male" or "female")

**Response (200 OK):**
```json
{
  "audio_id": "550e8400-e29b-41d4-a716-446655440000",
  "duration": 3,
  "file_size": 9600,
  "file_path": "/tmp/piper-audio-output/550e8400-e29b-41d4-a716-446655440000_ulaw.wav",
  "local_url": "http://localhost:5000/api/audio/550e8400-e29b-41d4-a716-446655440000",
  "status": "ready",
  "generated_at": "2026-08-05T15:30:00.000000"
}
```

**Response (400 Bad Request):**
```json
{
  "error": "text exceeds 500 characters",
  "length": 512
}
```

**Response (500 Server Error):**
```json
{
  "error": "TTS generation failed",
  "details": "Piper error message here"
}
```

---

### 3. Download Audio

**Endpoint:** `GET /api/audio/<audio_id>`

Download previously generated audio file.

**Parameters:**
- `audio_id` (required): UUID from generation response

**Response (200 OK):**
Returns binary WAV file (audio/wav)

**Response (404 Not Found):**
```json
{
  "error": "Audio file not found"
}
```

---

### 4. Delete Audio

**Endpoint:** `DELETE /api/audio/<audio_id>`

Delete an audio file from storage.

**Parameters:**
- `audio_id` (required): UUID of audio to delete

**Response (200 OK):**
```json
{
  "status": "deleted"
}
```

**Response (404 Not Found):**
```json
{
  "error": "Audio file not found"
}
```

---

### 5. Service Statistics

**Endpoint:** `GET /api/stats`

Get service usage statistics.

**Response (200 OK):**
```json
{
  "total_audio_files": 42,
  "total_disk_usage_bytes": 425984,
  "output_directory": "/tmp/piper-audio-output",
  "timestamp": "2026-08-05T15:30:00.000000"
}
```

---

## Testing

### 1. Health Check

```bash
curl http://localhost:5000/health
```

Expected: `{"status": "healthy", ...}`

### 2. Generate Audio

```bash
curl -X POST http://localhost:5000/api/tts/generate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello world",
    "language": "en-US",
    "voice_gender": "male"
  }'
```

Expected: Returns `audio_id`, `duration`, `local_url`, etc.

### 3. Download Audio

```bash
AUDIO_ID="<from_previous_response>"
curl http://localhost:5000/api/audio/$AUDIO_ID -o test.wav
ffplay test.wav
```

### 4. Statistics

```bash
curl http://localhost:5000/api/stats
```

### 5. Test with Backend

```bash
# From backend machine:
curl -X POST http://piper-service-ip:5000/api/tts/generate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Backend test",
    "language": "en-US",
    "voice_gender": "male"
  }'
```

## Backend Integration

### Configuration

Set environment variable in backend `.env`:

```bash
PIPER_SERVICE_URL=http://localhost:5000  # Local testing
# or
PIPER_SERVICE_URL=http://piper-server-ip:5000  # Remote VPS
USE_EXTERNAL_PIPER=true
```

### Usage in Go Backend

```go
// Call Piper service
resp, err := http.Post(
    "http://localhost:5000/api/tts/generate",
    "application/json",
    bytes.NewBuffer(requestBody),
)

// Get audio URL
var result struct {
    AudioID string `json:"audio_id"`
    LocalURL string `json:"local_url"`
    Duration int `json:"duration"`
}
json.Unmarshal(body, &result)

// Download and upload to CDN
audioFile, _ := downloadAudio(result.LocalURL)
cdnURL, _ := uploadToCDN(audioFile)
```

## Configuration

### Environment Variables

```bash
# Model paths
PIPER_MODEL_PATH=/opt/piper-models/en_US-male-medium.onnx
PIPER_CONFIG_PATH=/opt/piper-models/en_US-male-medium.onnx.json

# Output directory
PIPER_OUTPUT_DIR=/tmp/piper-audio-output

# Flask settings
FLASK_ENV=production
FLASK_DEBUG=false
```

### Customization

Edit `app.py` to:
- Change default language/voice
- Add more voice models
- Modify audio format/quality
- Adjust text length limits
- Add authentication

## Performance Considerations

### Audio Generation Time
- ~1-3 seconds per message (depends on text length)
- First run: +5-10 seconds for model loading

### Memory Usage
- Model loading: ~500MB
- Per request: ~100MB temporary
- Recommend 2GB+ RAM

### Storage
- Each audio file: 8-50KB (depends on duration)
- With cleanup: ~1GB per day

### Scaling

For high volume, consider:
1. Multiple Piper instances (round-robin load balancing)
2. Redis caching for common messages
3. Async job queue (Celery)
4. CDN for audio distribution

## Troubleshooting

### Service Won't Start

```bash
# Check Python version
python3.9 --version

# Check FFmpeg
ffmpeg -version

# Check model files
ls -lh /opt/piper-models/

# Check permissions
chmod 777 /tmp/piper-audio-output
```

### Models Not Found

```bash
# Download models
mkdir -p /opt/piper-models
cd /opt/piper-models
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/male/medium/en_US-male-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/male/medium/en_US-male-medium.onnx.json
```

### Audio Generation Timeout

- Reduce text length
- Increase server resources (RAM, CPU)
- Check Piper service logs

### Connection Refused (Backend to Service)

```bash
# Verify service is running
curl http://localhost:5000/health

# Check firewall
sudo ufw allow 5000/tcp

# Check CORS headers
curl -H "Origin: http://backend-ip" http://localhost:5000/health
```

## Logs

### Local Development

Logs print to console.

### Production (Systemd)

```bash
# View logs
sudo journalctl -u piper-tts

# Follow logs
sudo journalctl -u piper-tts -f

# Last 50 lines
sudo journalctl -u piper-tts -n 50

# Since last boot
sudo journalctl -u piper-tts -b
```

## Deployment Checklist

- [ ] Python 3.9 installed
- [ ] FFmpeg installed
- [ ] Virtual environment created
- [ ] Dependencies installed
- [ ] Piper models downloaded
- [ ] Output directory created with correct permissions
- [ ] Environment variables set
- [ ] Firewall allows port 5000
- [ ] Health check passes
- [ ] Systemd service configured (production)
- [ ] Service starts on boot
- [ ] Logs are being written
- [ ] Backend can connect to service

## Support

For issues with:
- **Piper TTS**: https://github.com/rhasspy/piper
- **Flask**: https://flask.palletsprojects.com/
- **FFmpeg**: https://ffmpeg.org/

## License

Same as main project (if open source)

## Version History

- **v1.0.0** (Aug 5, 2026) - Initial release
  - Basic TTS generation
  - WAV to ULAW conversion
  - REST API endpoints
  - Health checks
  - Logging and error handling
