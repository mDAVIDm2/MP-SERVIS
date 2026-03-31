"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isClientAppRequest = isClientAppRequest;
function isClientAppRequest(req) {
    const raw = req.headers['x-autohub-app'] ?? req.headers['X-AutoHub-App'];
    return String(raw ?? '').toLowerCase() === 'client';
}
//# sourceMappingURL=request-app.util.js.map