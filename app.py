"""
Piper TTS Microservice
External service for text-to-speech generation
"""

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import subprocess
import os
import json
import uuid
import logging
from datetime import datetime
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration
MODELS_BASE_DIR = os.getenv('PIPER_MODELS_DIR', '/opt/piper-models')
OUTPUT_DIR = os.getenv('PIPER_OUTPUT_DIR', '/tmp/piper-audio-output')
MAX_TEXT_LENGTH = 10000 # Maximum characters allowed in input text

# Available voices - maps frontend voice IDs to Piper model names
# Format: "en-US-male-medium" -> "en_US-ryan-medium" (Ryan = male voice)
AVAILABLE_VOICES = {
    # English - US (Based on actual Piper speaker models)
    "en-US-male-medium": "en_US-ryan-medium",      # Male speaker (Ryan)
    "en-US-female-medium": "en_US-amy-medium",      # Female speaker (Amy)
    
    # Add more voices as models are downloaded
    # Male voices: Ryan, Lessac, Kusal
    # Female voices: Amy, Kathleen, Kristin
    # Multispeaker: LibriTTS (904 speakers)
}

DEFAULT_VOICE = "en-US-male-medium"

# Ensure output directory exists
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

logger.info(f"Piper TTS Service starting...")
logger.info(f"Models Directory: {MODELS_BASE_DIR}")
logger.info(f"Output Dir: {OUTPUT_DIR}")
logger.info(f"Available voices: {len(AVAILABLE_VOICES)}")


def get_model_paths(voice_id):
    """Get model and config file paths for a given voice ID"""
    if voice_id not in AVAILABLE_VOICES:
        logger.warning(f"Unknown voice: {voice_id}")
        return None, None
    
    model_name = AVAILABLE_VOICES[voice_id]
    model_path = os.path.join(MODELS_BASE_DIR, f"{model_name}.onnx")
    config_path = os.path.join(MODELS_BASE_DIR, f"{model_name}.onnx.json")
    
    return model_path, config_path


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint - shows available voices"""
    try:
        available_models = []
        if os.path.exists(MODELS_BASE_DIR):
            for voice_id, model_name in AVAILABLE_VOICES.items():
                model_path = os.path.join(MODELS_BASE_DIR, f"{model_name}.onnx")
                config_path = os.path.join(MODELS_BASE_DIR, f"{model_name}.onnx.json")
                if os.path.exists(model_path) and os.path.exists(config_path):
                    available_models.append(voice_id)
        
        status = "healthy" if len(available_models) > 0 else "degraded"
        status_code = 200 if len(available_models) > 0 else 206
        
        return jsonify({
            "status": status,
            "service": "piper-tts",
            "version": "1.0.0",
            "models_directory": MODELS_BASE_DIR,
            "total_voices_configured": len(AVAILABLE_VOICES),
            "voices_available": available_models,
            "default_voice": DEFAULT_VOICE,
            "timestamp": datetime.now().isoformat()
        }), status_code
    
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({"status": "unhealthy", "error": str(e)}), 503


@app.route('/api/voices', methods=['GET'])
def list_voices():
    """List all available voices and their status"""
    try:
        voices_info = {}
        available_count = 0
        
        for voice_id, model_name in AVAILABLE_VOICES.items():
            model_path = os.path.join(MODELS_BASE_DIR, f"{model_name}.onnx")
            config_path = os.path.join(MODELS_BASE_DIR, f"{model_name}.onnx.json")
            is_available = os.path.exists(model_path) and os.path.exists(config_path)
            
            if is_available:
                available_count += 1
            
            # Parse voice_id
            parts = voice_id.split('-')
            language_map = {
                'en': 'English',
                'es': 'Spanish',
                'fr': 'French',
                'de': 'German',
                'it': 'Italian',
                'pt': 'Portuguese',
                'nl': 'Dutch',
                'ru': 'Russian',
                'pl': 'Polish'
            }
            
            lang_code = parts[0]
            country = parts[1] if len(parts) > 1 else ''
            gender = parts[2] if len(parts) > 2 else 'unknown'
            quality = parts[3] if len(parts) > 3 else 'unknown'
            language_name = f"{language_map.get(lang_code, 'Unknown')} ({country})" if country else language_map.get(lang_code, 'Unknown')
            
            voices_info[voice_id] = {
                "available": is_available,
                "language": language_name,
                "gender": gender,
                "quality": quality,
                "model_name": model_name
            }
        
        return jsonify({
            "available_voices": voices_info,
            "default_voice": DEFAULT_VOICE,
            "total_configured": len(AVAILABLE_VOICES),
            "total_available": available_count,
            "timestamp": datetime.now().isoformat()
        }), 200
    
    except Exception as e:
        logger.error(f"Error listing voices: {str(e)}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/tts/generate', methods=['POST'])
def generate_tts():
    """Generate TTS audio from text"""
    try:
        data = request.json or {}
        
        # Validate request
        if not data or 'text' not in data:
            return jsonify({"error": "text field is required"}), 400
        
        text = data.get('text', '').strip()
        
        # Get voice (required)
        voice = data.get('voice', None)
        if not voice:
            return jsonify({
                "error": "voice field is required",
                "available_voices": list(AVAILABLE_VOICES.keys()),
                "default_voice": DEFAULT_VOICE
            }), 400
        
        # Validate text
        if not text:
            return jsonify({"error": "text cannot be empty"}), 400
        
        if len(text) > MAX_TEXT_LENGTH:
            return jsonify({
                "error": f"text exceeds {MAX_TEXT_LENGTH} characters",
                "length": len(text),
                "max_length": MAX_TEXT_LENGTH
            }), 400
        
        # Validate voice exists
        if voice not in AVAILABLE_VOICES:
            return jsonify({
                "error": f"Unknown voice: {voice}",
                "available_voices": list(AVAILABLE_VOICES.keys()),
                "default_voice": DEFAULT_VOICE,
                "hint": "Use GET /api/voices to see available voices"
            }), 400
        
        logger.info(f"TTS Request: text_len={len(text)}, voice={voice}")
        
        # Get model paths
        model_path, config_path = get_model_paths(voice)
        if not model_path or not config_path:
            return jsonify({"error": f"Model paths not found for voice: {voice}"}), 500
        
        # Check if model files exist
        if not os.path.exists(model_path) or not os.path.exists(config_path):
            return jsonify({
                "error": f"Model files not found for voice: {voice}",
                "expected_model": model_path,
                "expected_config": config_path
            }), 503
        
        # Generate unique audio ID
        audio_id = str(uuid.uuid4())
        output_wav = os.path.join(OUTPUT_DIR, f"{audio_id}.wav")
        output_ulaw = os.path.join(OUTPUT_DIR, f"{audio_id}_ulaw.wav")
        
        # Step 1: Generate WAV using Piper
        logger.info(f"[{audio_id}] Generating WAV with Piper (voice={voice})...")
        cmd = [
            'python3', '-m', 'piper',
            '--model', model_path,
            '--config', config_path,
            '--output-file', output_wav,
            '--no-normalize'
        ]
        
        try:
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            stdout, stderr = process.communicate(
                input=text.encode('utf-8'),
                timeout=30
            )
            
            if process.returncode != 0:
                error_msg = stderr.decode('utf-8', errors='ignore')
                logger.error(f"[{audio_id}] Piper generation failed: {error_msg}")
                return jsonify({
                    "error": "TTS generation failed",
                    "details": error_msg,
                    "voice": voice
                }), 500
            
            if not os.path.exists(output_wav):
                logger.error(f"[{audio_id}] WAV file not created after Piper")
                return jsonify({"error": "WAV file not generated"}), 500
            
            wav_size = os.path.getsize(output_wav)
            logger.info(f"[{audio_id}] WAV generated: {wav_size} bytes")
        
        except subprocess.TimeoutExpired:
            logger.error(f"[{audio_id}] Piper timeout")
            process.kill()
            return jsonify({"error": "TTS generation timeout"}), 504
        except Exception as e:
            logger.error(f"[{audio_id}] Piper execution error: {str(e)}")
            return jsonify({"error": f"Piper error: {str(e)}"}), 500
        
        # Step 2: Convert to ULAW 8kHz (Twilio compatible)
        logger.info(f"[{audio_id}] Converting to ULAW 8kHz...")
        ffmpeg_cmd = [
            'ffmpeg', '-i', output_wav,
            '-codec:a', 'pcm_mulaw',
            '-ar', '8000',
            '-ac', '1',
            '-y',
            output_ulaw
        ]
        
        try:
            process = subprocess.Popen(
                ffmpeg_cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            stdout, stderr = process.communicate(timeout=30)
            
            if process.returncode != 0:
                error_msg = stderr.decode('utf-8', errors='ignore')
                logger.error(f"[{audio_id}] FFmpeg conversion failed: {error_msg}")
                if os.path.exists(output_wav):
                    output_ulaw = output_wav
                else:
                    return jsonify({
                        "error": "Audio conversion failed",
                        "details": error_msg
                    }), 500
            
            if not os.path.exists(output_ulaw):
                logger.error(f"[{audio_id}] ULAW file not created")
                return jsonify({"error": "ULAW conversion failed"}), 500
            
            ulaw_size = os.path.getsize(output_ulaw)
            logger.info(f"[{audio_id}] ULAW generated: {ulaw_size} bytes")
        
        except subprocess.TimeoutExpired:
            logger.error(f"[{audio_id}] FFmpeg timeout")
            process.kill()
            return jsonify({"error": "Audio conversion timeout"}), 504
        except Exception as e:
            logger.error(f"[{audio_id}] FFmpeg error: {str(e)}")
            if os.path.exists(output_wav):
                output_ulaw = output_wav
            else:
                return jsonify({"error": f"Conversion error: {str(e)}"}), 500
        
        # Calculate duration
        file_size = os.path.getsize(output_ulaw)
        duration = file_size / (8000 * 1)  # 8kHz mono, 1 byte per sample (ULAW)
        
        # Clean up original WAV
        if os.path.exists(output_wav) and output_wav != output_ulaw:
            try:
                os.remove(output_wav)
            except:
                pass
        
        logger.info(f"[{audio_id}] TTS Complete: duration={duration:.2f}s, size={file_size} bytes, voice={voice}")
        
        return jsonify({
            "audio_id": audio_id,
            "duration": int(duration),
            "file_size": file_size,
            "file_path": output_ulaw,
            "local_url": f"http://localhost:5000/api/audio/{audio_id}",
            "voice": voice,
            "status": "ready",
            "generated_at": datetime.now().isoformat()
        }), 200
    
    except Exception as e:
        logger.error(f"Unexpected error in generate_tts: {str(e)}")
        return jsonify({"error": f"Unexpected error: {str(e)}"}), 500


@app.route('/api/audio/<audio_id>', methods=['GET'])
def get_audio(audio_id):
    """Download generated audio file"""
    try:
        if not uuid.UUID(audio_id):
            return jsonify({"error": "Invalid audio_id"}), 400
    except (ValueError, AttributeError):
        return jsonify({"error": "Invalid audio_id"}), 400
    
    try:
        file_path = os.path.join(OUTPUT_DIR, f"{audio_id}_ulaw.wav")
        
        if not os.path.exists(file_path):
            logger.warning(f"Audio file not found: {file_path}")
            return jsonify({"error": "Audio file not found"}), 404
        
        logger.info(f"Serving audio: {file_path}")
        return send_file(
            file_path,
            mimetype='audio/wav',
            as_attachment=True,
            download_name=f"{audio_id}.wav"
        )
    
    except Exception as e:
        logger.error(f"Error serving audio {audio_id}: {str(e)}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/audio/<audio_id>/delete', methods=['DELETE'])
def delete_audio(audio_id):
    """Delete an audio file"""
    try:
        if not uuid.UUID(audio_id):
            return jsonify({"error": "Invalid audio_id"}), 400
    except (ValueError, AttributeError):
        return jsonify({"error": "Invalid audio_id"}), 400
    
    try:
        file_path = os.path.join(OUTPUT_DIR, f"{audio_id}_ulaw.wav")
        
        if os.path.exists(file_path):
            os.remove(file_path)
            logger.info(f"Deleted audio: {file_path}")
            return jsonify({"status": "deleted"}), 200
        else:
            return jsonify({"error": "Audio file not found"}), 404
    
    except Exception as e:
        logger.error(f"Error deleting audio {audio_id}: {str(e)}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get service statistics"""
    try:
        audio_files = os.listdir(OUTPUT_DIR)
        total_files = len(audio_files)
        total_size = sum(
            os.path.getsize(os.path.join(OUTPUT_DIR, f))
            for f in audio_files
        )
        
        return jsonify({
            "total_audio_files": total_files,
            "total_disk_usage_bytes": total_size,
            "output_directory": OUTPUT_DIR,
            "timestamp": datetime.now().isoformat()
        }), 200
    
    except Exception as e:
        logger.error(f"Error getting stats: {str(e)}")
        return jsonify({"error": str(e)}), 500


@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {str(error)}")
    return jsonify({"error": "Internal server error"}), 500


if __name__ == '__main__':
    logger.info("Starting Piper TTS Flask service...")
    logger.info("Available endpoints:")
    logger.info("  GET  /health - Health check")
    logger.info("  GET  /api/voices - List voices")
    logger.info("  POST /api/tts/generate - Generate TTS audio")
    logger.info("  GET  /api/audio/<id> - Download audio")
    logger.info("  GET  /api/stats - Service statistics")
    
    app.run(host='0.0.0.0', port=5000, debug=False)
