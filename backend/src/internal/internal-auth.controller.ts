import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { InternalAuthService, InternalLoginResult } from './internal-auth.service';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { InternalCurrentOperator } from './internal-current-operator.decorator';
import { InternalOperator } from './internal-operator.entity';
import { InternalLoginDto } from './dto/internal-login.dto';

@Controller('internal/auth')
export class InternalAuthController {
  constructor(private auth: InternalAuthService) {}

  @Post('login')
  async login(@Body() body: InternalLoginDto): Promise<InternalLoginResult> {
    return this.auth.login(body.email.trim().toLowerCase(), body.password);
  }

  @Get('me')
  @UseGuards(InternalJwtAuthGuard)
  async me(@InternalCurrentOperator() operator: InternalOperator) {
    return {
      id: operator.id,
      email: operator.email,
      name: operator.name || operator.email.split('@')[0],
      role: operator.role,
    };
  }
}
