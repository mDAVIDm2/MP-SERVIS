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
exports.CarGeneration = void 0;
const typeorm_1 = require("typeorm");
const car_model_entity_1 = require("./car-model.entity");
let CarGeneration = class CarGeneration {
};
exports.CarGeneration = CarGeneration;
__decorate([
    (0, typeorm_1.PrimaryGeneratedColumn)('increment'),
    __metadata("design:type", Number)
], CarGeneration.prototype, "id", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'model_id', type: 'int' }),
    __metadata("design:type", Number)
], CarGeneration.prototype, "modelId", void 0);
__decorate([
    (0, typeorm_1.Column)({ type: 'varchar', length: 128 }),
    __metadata("design:type", String)
], CarGeneration.prototype, "name", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'year_from', type: 'int', nullable: true }),
    __metadata("design:type", Object)
], CarGeneration.prototype, "yearFrom", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'year_to', type: 'int', nullable: true }),
    __metadata("design:type", Object)
], CarGeneration.prototype, "yearTo", void 0);
__decorate([
    (0, typeorm_1.Column)({ name: 'sort_order', type: 'int', default: 0 }),
    __metadata("design:type", Number)
], CarGeneration.prototype, "sortOrder", void 0);
__decorate([
    (0, typeorm_1.ManyToOne)(() => car_model_entity_1.CarModel, { onDelete: 'CASCADE' }),
    (0, typeorm_1.JoinColumn)({ name: 'model_id' }),
    __metadata("design:type", car_model_entity_1.CarModel)
], CarGeneration.prototype, "model", void 0);
exports.CarGeneration = CarGeneration = __decorate([
    (0, typeorm_1.Entity)('car_generations')
], CarGeneration);
//# sourceMappingURL=car-generation.entity.js.map