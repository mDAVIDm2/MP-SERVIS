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
exports.MasterSchedule = void 0;
const typeorm_1 = require("typeorm");
const staff_member_entity_1 = require("./staff-member.entity");
let MasterSchedule = class MasterSchedule {
};
exports.MasterSchedule = MasterSchedule;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('uuid'),
    __metadata("design:type", String)
], MasterSchedule.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'master_id' }),
    __metadata("design:type", String)
], MasterSchedule.prototype, "masterId", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'day_of_week', type: 'smallint' }),
    __metadata("design:type", Number)
], MasterSchedule.prototype, "dayOfWeek", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'start_time', type: 'varchar', length: 5, default: '09:00' }),
    __metadata("design:type", String)
], MasterSchedule.prototype, "startTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'end_time', type: 'varchar', length: 5, default: '18:00' }),
    __metadata("design:type", String)
], MasterSchedule.prototype, "endTime", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'is_working_day', default: true }),
    __metadata("design:type", Boolean)
], MasterSchedule.prototype, "isWorkingDay", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => staff_member_entity_1.StaffMember, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'master_id' }),
    __metadata("design:type", staff_member_entity_1.StaffMember)
], MasterSchedule.prototype, "master", void 0);
exports.MasterSchedule = MasterSchedule = __decorate([
    (0, typeorm_1.Entity)('master_schedules')
], MasterSchedule);
//# sourceMappingURL=master-schedule.entity.js.map