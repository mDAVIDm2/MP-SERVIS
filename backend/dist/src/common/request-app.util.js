"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isClientAppRequest = isClientAppRequest;
function isClientAppRequest(req) {
    const raw = req.headers['x-mp-servis-app'] ?? req.headers['X-MP-Servis-App'];
    return String(raw ?? '').toLowerCase() === 'client';
}
//# sourceMappingURL=request-app.util.js.map