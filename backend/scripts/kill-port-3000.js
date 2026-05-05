/**
 * Освобождает порт приложения (по умолчанию 3000), убивая LISTENING PID.
 * prestart запускается до Nest, поэтому читаем PORT из .env в cwd (папка backend).
 */
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

function readPortFromEnvFile() {
  const envPath = path.join(process.cwd(), '.env');
  try {
    const raw = fs.readFileSync(envPath, 'utf8');
    const m = raw.match(/^\s*PORT\s*=\s*(\S+)/m);
    if (m) {
      const n = parseInt(m[1], 10);
      if (!Number.isNaN(n)) return n;
    }
  } catch (_) {}
  return null;
}

const port = process.env.PORT || readPortFromEnvFile() || 3000;

function killPort(port) {
  try {
    if (process.platform === 'win32') {
      let out;
      try {
        out = execSync(`netstat -ano | findstr :${port}`, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
      } catch (_) {
        return;
      }
      const lines = out.trim().split('\n').filter((l) => l.includes('LISTENING'));
      const pids = new Set();
      for (const line of lines) {
        const parts = line.trim().split(/\s+/);
        const pid = parts[parts.length - 1];
        if (pid && /^\d+$/.test(pid)) pids.add(pid);
      }
      for (const pid of pids) {
        try {
          execSync(`taskkill /PID ${pid} /F`, { stdio: 'ignore' });
          console.log(`[kill-port] Освобождён порт ${port} (PID ${pid})`);
        } catch (_) {}
      }
      if (pids.size > 0) console.log(`[kill-port] Освобождён порт ${port}`);
    } else {
      execSync(`lsof -ti :${port} | xargs kill -9 2>/dev/null || true`, { stdio: 'inherit' });
      console.log(`[kill-port] Порт ${port} освобождён`);
    }
  } catch (e) {
    if (e.status !== 1 && e.stdout !== undefined) throw e;
  }
}

killPort(port);
