import { Injectable } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Локальное хранилище под uploads/media/{storageKey}.
 * storageKey — относительный путь без ".." (проверяется в MediaService).
 */
@Injectable()
export class LocalStorageService {
  private readonly root = path.join(process.cwd(), 'uploads', 'media');

  async putObject(storageKey: string, body: Buffer): Promise<void> {
    const full = this.resolveSafe(storageKey);
    await fs.promises.mkdir(path.dirname(full), { recursive: true });
    await fs.promises.writeFile(full, body);
  }

  getAbsolutePath(storageKey: string): string {
    return this.resolveSafe(storageKey);
  }

  async deleteObject(storageKey: string): Promise<void> {
    const full = this.resolveSafe(storageKey);
    try {
      await fs.promises.unlink(full);
    } catch {
      /* ignore */
    }
  }

  private resolveSafe(storageKey: string): string {
    const normalized = storageKey.replace(/\\/g, '/').replace(/^\/+/, '');
    if (normalized.includes('..') || normalized.includes('\0')) {
      throw new Error('Invalid storage key');
    }
    const full = path.join(this.root, ...normalized.split('/'));
    const rootResolved = path.resolve(this.root);
    const fullResolved = path.resolve(full);
    if (!fullResolved.startsWith(rootResolved + path.sep) && fullResolved !== rootResolved) {
      throw new Error('Invalid storage path');
    }
    return fullResolved;
  }
}
