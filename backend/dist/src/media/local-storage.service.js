"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.LocalStorageService = void 0;
const common_1 = require("@nestjs/common");
const fs = require("fs");
const path = require("path");
let LocalStorageService = class LocalStorageService {
    constructor() {
        this.root = path.join(process.cwd(), 'uploads', 'media');
    }
    async putObject(storageKey, body) {
        const full = this.resolveSafe(storageKey);
        await fs.promises.mkdir(path.dirname(full), { recursive: true });
        await fs.promises.writeFile(full, body);
    }
    getAbsolutePath(storageKey) {
        return this.resolveSafe(storageKey);
    }
    async deleteObject(storageKey) {
        const full = this.resolveSafe(storageKey);
        try {
            await fs.promises.unlink(full);
        }
        catch {
        }
    }
    resolveSafe(storageKey) {
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
};
exports.LocalStorageService = LocalStorageService;
exports.LocalStorageService = LocalStorageService = __decorate([
    (0, common_1.Injectable)()
], LocalStorageService);
//# sourceMappingURL=local-storage.service.js.map