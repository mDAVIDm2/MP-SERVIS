"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.InternalCurrentOperator = void 0;
const common_1 = require("@nestjs/common");
exports.InternalCurrentOperator = (0, common_1.createParamDecorator)((data, ctx) => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
});
//# sourceMappingURL=internal-current-operator.decorator.js.map