"""
Piper TTS Microservice
External service for text-to-speech generation
"""

from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import subprocess
import os
import json
import tempfile
import uuid
import logging
from datetime import datetime
from pathlib import Path
import shutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration
PIPER_MODEL_PATH = os.getenv('PIPER_MODEL_PATH', '/opt/piper-models/en_US-male-medium.onnx')
PIPER_CONFIG_PATH = os.getenv('PIPER_CONFIG_PATH', '/opt/piper-models/en_US-male-medium.onnx.json')
OUTPUT_DIR = os.getenv('PIPER_OUTPUT_DIR', '/tmp/piper-audio-output')
MAX_TEXT_LENGTH = 500
CLEANUP_OLDER_THAN_HOURS = 24

# Ensure output directory exists
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

logger.info(f"Piper TTS Service starting...")
logger.info(f"Model: {PIPER_MODEL_PATH}")
logger.info(f"Config: {PIPER_CONFIG_PATH}")
logger.info(f"Output Dir: {OUTPUT_DIR}")


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        # Check if model files exist
        model_exists = os.path.exists(PIPER_MODEL_PATH)
        config_exists = os.path.exists(PIPER_CONFIG_PATH)
        
        if not model_exists or not config_exists:
            return jsonify({
                "status": "unhealthy",
                "service": "piper-tts",
                "error": "Model files not found",
                "model_exists": model_exists,
                "config_exists": config_exists,
                "timestamp": datetime.now().isoformat()
            }), 503
        
        return jsonify({
            "status": "healthy",
            "service": "piper-tts",
            "version": "1.0.0",
            "model_path": PIPER_MODEL_PATH,
            "timestamp": datetime.now().isoformat()
        }), 200
    
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            "status": "unhealthy",
            "error": str(e)
        }), 503


@app.route('/api/tts/generate', methods=['POST'])
def generate_tts():
    """
    Generate TTS audio
    
    Expected JSON:
    {
      "text": "Hello world",
      "language": "en-US",
      "voice_gender": "male"
    }
    
    Returns:
    {
      "audio_id": "uuid",
      "duration": 3,
      "file_size": 9600,
      "file_path": "/tmp/piper-audio-output/uuid_ulaw.wav",
      "local_url": "http://localhost:5000/api/audio/uuid",
      "status": "ready"
    }
    """
    try:
        data = request.json or {}
        
        # Validate request
        if not data or 'text' not in data:
            logger.warning("TTS request missing 'text' field")
            return jsonify({"error": "text field is required"}), 400
        
        text = data.get('text', '').strip()
        language = data.get('language', 'en-US')
        voice_gender = data.get('voice_gender', 'male')
        
        # Validate text
        if not text:
            logger.warning("TTS request with empty text")
            return jsonify({"error": "text cannot be empty"}), 400
        
        if len(text) > MAX_TEXT_LENGTH:
            logger.warning(f"TTS text exceeds {MAX_TEXT_LENGTH} chars: {len(text)}")
            return jsonify({
                "error": f"text exceeds {MAX_TEXT_LENGTH} characters",
                "length": len(text)
            }), 400
        
        logger.info(f"TTS Request: text_len={len(text)}, lang={language}, gender={voice_gender}")
        
        # Generate unique audio ID
        audio_id = str(uuid.uuid4())
        output_wav = os.path.join(OUTPUT_DIR, f"{audio_id}.wav")
        output_ulaw = os.path.join(OUTPUT_DIR, f"{audio_id}_ulaw.wav")
        
        # Step 1: Generate WAV using Piper
        logger.info(f"[{audio_id}] Generating WAV with Piper...")
        cmd = [
            'python3.9', '-m', 'piper',
            '--model', PIPER_MODEL_PATH,
            '--config', PIPER_CONFIG_PATH,
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
                    "details": error_msg
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
            'ffmpeg',
            '-i', output_wav,
            '-codec:a', 'pcm_mulaw',
            '-ar', '8000',
            '-ac', '1',
            '-y',  # Overwrite output file
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
                # Try to return original WAV if conversion fails
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
        
        logger.info(f"[{audio_id}] TTS Complete: duration={duration:.2f}s, size={file_size} bytes")
        
        return jsonify({
            "audio_id": audio_id,
            "duration": int(duration),
            "file_size": file_size,
            "file_path": output_ulaw,
            "local_url": f"http://localhost:5000/api/audio/{audio_id}",
            "status": "ready",
            "generated_at": datetime.now().isoformat()
        }), 200
    
    except Exception as e:
        logger.error(f"Unexpected error in generate_tts: {str(e)}")
        return jsonify({"error": f"Unexpected error: {str(e)}"}), 500


@app.route('/api/audio/<audio_id>', methods=['GET'])
def get_audio(audio_id):
    """
    Download generated audio file
    
    Returns the ULAW WAV file
    """
    try:
        # Validate audio_id to prevent directory traversal
        if not uuid.UUID(audio_id):
            logger.warning(f"Invalid audio_id format: {audio_id}")
            return jsonify({"error": "Invalid audio_id"}), 400
    except (ValueError, AttributeError):
        logger.warning(f"Invalid audio_id: {audio_id}")
        return jsonify({"error": "Invalid audio_id"}), 400
    
    try:
        file_path = os.path.join(OUTPUT_DIR, f"{audio_id}_ulaw.wav")
        
        # Check if file exists
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
    """
    Delete an audio file
    """
    try:
        # Validate audio_id
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
    """
    Get service statistics
    """
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
    logger.info("  POST /api/tts/generate - Generate TTS audio")
    logger.info("  GET  /api/audio/<id> - Download audio")
    logger.info("  GET  /api/stats - Service statistics")
    
    app.run(host='0.0.0.0', port=5000, debug=False)
