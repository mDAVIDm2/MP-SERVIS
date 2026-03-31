"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.LogoutDto = exports.RefreshDto = exports.VerifyCodeDto = exports.SendCodeDto = void 0;
const class_validator_1 = require("class-validator");
class SendCodeDto {
}
exports.SendCodeDto = SendCodeDto;
__decorate([
    (0, class_validator_1.ValidateIf)((o) => !o.phone || String(o.phone).trim() === ''),
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], SendCodeDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => !o.email || String(o.email).trim() === ''),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[\d\s+()-]{10,24}$/, { message: 'Некорректный телефон' }),
    __metadata("design:type", String)
], SendCodeDto.prototype, "phone", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsIn)(['email', 'sms', 'voice', 'flash', 'console']),
    __metadata("design:type", String)
], SendCodeDto.prototype, "channel", void 0);
class VerifyCodeDto {
}
exports.VerifyCodeDto = VerifyCodeDto;
__decorate([
    (0, class_validator_1.ValidateIf)((o) => !o.phone || String(o.phone).trim() === ''),
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => !o.email || String(o.email).trim() === ''),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^[\d\s+()-]{10,24}$/),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "phone", void 0);
__decorate([
    (0, class_validator_1.IsUUID)('4'),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "challenge_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(6, 6),
    (0, class_validator_1.Matches)(/^\d{6}$/),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "code", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(0, 32),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "phone_unverified", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(0, 120),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "name", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(0, 128),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "device_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(0, 256),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "device_name", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(0, 32),
    __metadata("design:type", String)
], VerifyCodeDto.prototype, "platform", void 0);
class RefreshDto {
}
exports.RefreshDto = RefreshDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(40, 512),
    __metadata("design:type", String)
], RefreshDto.prototype, "refresh_token", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(0, 128),
    __metadata("design:type", String)
], RefreshDto.prototype, "device_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(0, 256),
    __metadata("design:type", String)
], RefreshDto.prototype, "device_name", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(0, 32),
    __metadata("design:type", String)
], RefreshDto.prototype, "platform", void 0);
class LogoutDto {
}
exports.LogoutDto = LogoutDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(40, 512),
    __metadata("design:type", String)
], LogoutDto.prototype, "refresh_token", void 0);
//# sourceMappingURL=auth.dto.js.map