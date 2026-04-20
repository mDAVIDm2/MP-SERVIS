import {
  BadRequestException,
  Body,
  Controller,
  ForbiddenException,
  Get,
  HttpCode,
  NotFoundException,
  Param,
  Post,
  Req,
  Res,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FilesInterceptor } from '@nestjs/platform-express';
import { Request, Response } from 'express';
import { isClientAppRequest } from '../common/request-app.util';
import { ChatsService } from './chats.service';

@Controller('chats')
@UseGuards(AuthGuard('jwt'))
export class ChatsController {
  constructor(private chats: ChatsService) {}

  /** Открыть или создать чат с поддержкой (по номеру из JWT). */
  @Post('support/open')
  async openSupport(@Req() req: Request & { user: { phone?: string } }) {
    const user = (req as any).user;
    const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
    if (!phone) throw new BadRequestException('В профиле не указан телефон');
    const chat = await this.chats.getOrCreateSupportChat(phone);
    return this.chats.getChatById(chat.id, null, phone, true);
  }

  /** Общий чат с выбранной точкой (карточка СТО → «Написать»). Только клиентское приложение. */
  @Post('open-organization')
  async openOrganizationChat(
    @Req() req: Request & { user: { phone?: string } },
    @Body() body: { organization_id?: string },
  ) {
    if (!isClientAppRequest(req)) {
      throw new ForbiddenException('Доступно только из клиентского приложения');
    }
    const orgId = body?.organization_id?.trim();
    if (!orgId) throw new BadRequestException('Укажите organization_id');
    const user = (req as any).user;
    const phone = user?.phone != null ? String(user.phone) : '';
    return this.chats.openOrganizationChatForClient(orgId, phone);
  }

  @Get()
  async list(@Req() req: Request & { user: { organizationId?: string | null; phone?: string } }) {
    const user = (req as any).user;
    const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
    if (isClientAppRequest(req)) {
      if (!phone) return { items: [] };
      try {
        return await this.chats.getChatsForClient(phone);
      } catch (err) {
        console.error('[Chats] getChatsForClient error:', err);
        return { items: [] };
      }
    }
    const orgId = user?.organizationId;
    if (orgId && phone) {
      try {
        return await this.chats.getChatsWithSupportForStaff(orgId, phone);
      } catch (err) {
        console.error('[Chats] getChatsWithSupportForStaff error:', err);
        return this.chats.getChats(orgId);
      }
    }
    if (orgId) return this.chats.getChats(orgId);
    if (!phone) return { items: [] };
    try {
      return await this.chats.getChatsForClient(phone);
    } catch (err) {
      console.error('[Chats] getChatsForClient error:', err);
      return { items: [] };
    }
  }

  @Get(':id/messages')
  async getMessages(
    @Param('id') id: string,
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string } },
  ) {
    const user = (req as any).user;
    const asClient = isClientAppRequest(req);
    const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
    const orgId = user?.organizationId ?? null;
    return this.chats.getMessagesForParticipant(id, orgId, phone || null, asClient);
  }

  @Get(':id/attachments/:assetId/file')
  async getAttachmentFile(
    @Param('id') chatId: string,
    @Param('assetId') assetId: string,
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string } },
    @Res() res: Response,
  ) {
    const user = (req as any).user;
    const asClient = isClientAppRequest(req);
    const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
    const orgId = user?.organizationId ?? null;
    const filePath = await this.chats.resolveChatAttachmentLocalPath(chatId, assetId, orgId, phone || null, asClient);
    if (!filePath) return res.status(404).send('Not found');
    return res.sendFile(filePath);
  }

  @Get(':id')
  async getOne(@Param('id') id: string, @Req() req: Request & { user: { organizationId?: string | null; phone?: string } }) {
    const user = (req as any).user;
    const orgId = user?.organizationId ?? null;
    const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
    const asClient = isClientAppRequest(req);
    return this.chats.getChatById(id, orgId, phone || null, asClient);
  }

  @Post(':id/read')
  @HttpCode(204)
  async markRead(@Param('id') id: string, @Req() req: Request & { user: { organizationId?: string | null; phone?: string } }) {
    const user = (req as any).user;
    const asClient = isClientAppRequest(req);
    const phone = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
    const orgId = user?.organizationId ?? null;
    await this.chats.markChatRead(id, orgId, phone || null, asClient);
  }

  @Post(':id/messages/with-media')
  @UseInterceptors(FilesInterceptor('files', 20))
  async sendMessageWithMedia(
    @Param('id') id: string,
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string; id?: string } },
    @Body() body: { text?: string },
    @UploadedFiles() files: Express.Multer.File[] | undefined,
  ) {
    const user = (req as any).user;
    const chat = await this.chats.findChatForAccess(id);
    if (!chat) throw new NotFoundException('Chat not found');
    const phoneNorm = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
    const orgId = user?.organizationId ?? null;
    const asClient = isClientAppRequest(req);
    this.chats.validateChatAccess(chat, orgId, phoneNorm || null, asClient);
    const cphone = (chat as any).clientPhone != null ? String((chat as any).clientPhone).replace(/\D/g, '') : '';
    const isSupportChat = chat.organizationId == null && !!cphone;
    const isFromClient =
      isClientAppRequest(req) || !user?.organizationId || (isSupportChat && !!user?.organizationId);
    let supportChannel: 'client' | 'business' | null = null;
    if (isSupportChat && isFromClient) {
      supportChannel = isClientAppRequest(req) ? 'client' : 'business';
    }
    return this.chats.sendMessageWithMedia(
      id,
      body ?? {},
      files,
      isFromClient,
      { userOrgId: orgId, userPhoneNorm: phoneNorm || null, asClient },
      { supportChannel, uploadedByUserId: user?.id ?? null },
    );
  }

  @Post(':id/messages')
  async sendMessage(
    @Param('id') id: string,
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string } },
    @Body() body: any,
  ) {
    const user = (req as any).user;
    const chat = await this.chats.findChatForAccess(id);
    if (!chat) throw new NotFoundException('Chat not found');
    const phoneNorm = user?.phone != null ? String(user.phone).replace(/\D/g, '') : '';
    const orgId = user?.organizationId ?? null;
    const asClient = isClientAppRequest(req);
    this.chats.validateChatAccess(chat, orgId, phoneNorm || null, asClient);
    const cphone = (chat as any).clientPhone != null ? String((chat as any).clientPhone).replace(/\D/g, '') : '';
    const isSupportChat = chat.organizationId == null && !!cphone;
    const isFromClient =
      isClientAppRequest(req) || !user?.organizationId || (isSupportChat && !!user?.organizationId);
    let supportChannel: 'client' | 'business' | null = null;
    if (isSupportChat && isFromClient) {
      supportChannel = isClientAppRequest(req) ? 'client' : 'business';
    }
    return this.chats.sendMessage(id, body, isFromClient, { supportChannel });
  }
}
