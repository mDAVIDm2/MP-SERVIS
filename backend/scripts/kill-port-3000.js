/**
 * Освобождает порт 3000 (убивает процесс, который его слушает).
 * Запускается перед `npm run dev`, чтобы избежать EADDRINUSE.
 */
const { execSync } = require('child_process');
const port = process.env.PORT || 3000;

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
