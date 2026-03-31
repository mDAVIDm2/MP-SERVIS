import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { InternalOperator } from './internal-operator.entity';

export const InternalCurrentOperator = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): InternalOperator => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);
