"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SKILL_LABELS = exports.Skill = void 0;
var Skill;
(function (Skill) {
    Skill["MAINTENANCE"] = "MAINTENANCE";
    Skill["ENGINE"] = "ENGINE";
    Skill["ELECTRICAL"] = "ELECTRICAL";
    Skill["DIAGNOSTICS"] = "DIAGNOSTICS";
    Skill["SUSPENSION"] = "SUSPENSION";
    Skill["TIRES"] = "TIRES";
    Skill["BODY"] = "BODY";
})(Skill || (exports.Skill = Skill = {}));
exports.SKILL_LABELS = {
    [Skill.MAINTENANCE]: 'ТО и обслуживание',
    [Skill.ENGINE]: 'Двигатель',
    [Skill.ELECTRICAL]: 'Электрика',
    [Skill.DIAGNOSTICS]: 'Диагностика',
    [Skill.SUSPENSION]: 'Подвеска',
    [Skill.TIRES]: 'Шины',
    [Skill.BODY]: 'Кузов',
};
//# sourceMappingURL=skill.enum.js.map