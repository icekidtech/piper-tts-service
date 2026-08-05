module.exports = {
  apps: [
    {
      name: 'piper-tts',
      script: 'app.py',
      interpreter: 'python3',
      instances: 1,
      exec_mode: 'fork',
      
      // Environment variables
      env: {
        PIPER_MODELS: '/opt/piper-models',
        FLASK_ENV: 'production',
        FLASK_DEBUG: 0,
        PORT: 5000
      },
      
      // Working directory
      cwd: '/home/hustleloop-admin/piper-tts-service',
      
      // Restart policy
      autorestart: true,
      max_memory_restart: '1G',
      
      // Logging
      error_file: '/var/log/pm2/piper-tts-error.log',
      out_file: '/var/log/pm2/piper-tts-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      
      // Advanced settings
      watch: false,
      ignore_watch: ['node_modules', '.git', 'uploads', 'temp'],
      max_restarts: 10,
      min_uptime: '10s',
      
      // Graceful shutdown
      kill_timeout: 5000,
      wait_ready: true,
      listen_timeout: 3000
    }
  ],

  // Deploy section (optional, for remote deployment)
  deploy: {
    production: {
      user: 'hustleloop-admin',
      host: 'your-vps-ip',
      ref: 'origin/main',
      repo: 'git@github.com:icekidtech/piper-tts-service.git',
      path: '/home/hustleloop-admin/piper-tts-service',
      'post-deploy': 'source venv/bin/activate && pip install -r requirements.txt && pm2 reload ecosystem.config.js --env production'
    }
  }
};
