import { Body, Controller, Get, HttpCode, Param, Post, UseGuards } from '@nestjs/common';
import { InternalJwtAuthGuard } from './internal-jwt.guard';
import { ChatsService } from '../chats/chats.service';

@Controller('internal/support-chats')
@UseGuards(InternalJwtAuthGuard)
export class InternalSupportChatsController {
  constructor(private readonly chats: ChatsService) {}

  @Get()
  async list() {
    return this.chats.listSupportChatsForInternal();
  }

  @Get(':id/messages')
  async messages(@Param('id') id: string) {
    return this.chats.getInternalSupportChatMessages(id);
  }

  @Post(':id/messages')
  async send(@Param('id') id: string, @Body() body: { text?: string }) {
    return this.chats.postInternalSupportOperatorMessage(id, body?.text ?? '');
  }

  @Post(':id/read')
  @HttpCode(204)
  async markRead(@Param('id') id: string) {
    await this.chats.markInternalSupportChatRead(id);
  }
}
