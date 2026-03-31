import { BadRequestException, Body, Controller, Get, NotFoundException, Param, Patch, Post, Req, Res, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Response, Request } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';
import { UseInterceptors, UploadedFile } from '@nestjs/common';
import { isClientAppRequest } from '../common/request-app.util';
import { OrdersService } from './orders.service';

@Controller('orders')
@UseGuards(AuthGuard('jwt'))
export class OrdersController {
  constructor(private orders: OrdersService) {}

  @Get()
  async list(@Req() req: Request & { user: { organizationId?: string | null; phone?: string } }) {
    const user = (req as any).user;
    const phone = user?.phone ? String(user.phone).replace(/\D/g, '') : '';
    if (isClientAppRequest(req)) {
      if (!phone) return { items: [] };
      return this.orders.findForClient(phone);
    }
    const orgId = user?.organizationId;
    if (orgId) return this.orders.findAll(orgId);
    if (!phone) return { items: [] };
    return this.orders.findForClient(phone);
  }

  @Get(':orderId/photos')
  async getPhotos(@Param('orderId') orderId: string) {
    const result = await this.orders.getOrderPhotos(orderId);
    if (!result) throw new Error('Not found');
    return result;
  }

  @Post(':orderId/photos')
  @UseInterceptors(FileInterceptor('file'))
  async addPhoto(
    @Param('orderId') orderId: string,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request & { user?: { id?: string } },
  ) {
    if (!file || !file.buffer) throw new Error('No file');
    const result = await this.orders.addOrderPhoto(orderId, file, {
      uploadedByUserId: req.user?.id ?? null,
    });
    if (!result) throw new Error('Not found');
    return result;
  }

  @Get(':orderId/photos/:photoId/file')
  async getPhotoFile(@Param('orderId') orderId: string, @Param('photoId') photoId: string, @Res() res: Response) {
    const filePath = await this.orders.getOrderPhotoFile(orderId, photoId);
    if (!filePath) return res.status(404).send('Not found');
    return res.sendFile(filePath);
  }

  @Get(':id')
  async get(
    @Param('id') id: string,
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string } },
  ) {
    const o = await this.orders.findOne(id);
    if (!o) throw new NotFoundException('Order not found');
    const user = (req as any).user;
    const clientMode = isClientAppRequest(req);
    const orgId = user?.organizationId;
    const userPhone = user?.phone ? this.orders.normalizePhoneForCompare(user.phone) : '';

    if (clientMode || (!orgId && user?.phone)) {
      const orderPhone = this.orders.normalizePhoneForCompare((o as any).client_phone);
      if (!userPhone || orderPhone !== userPhone) throw new NotFoundException('Order not found');
    } else if (orgId) {
      if ((o as any).organization_id !== orgId) throw new NotFoundException('Order not found');
    } else {
      throw new NotFoundException('Order not found');
    }
    return o;
  }

  @Post()
  async create(
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string; name?: string } },
    @Body() body: any,
  ) {
    const user = (req as any).user;
    const clientMode = isClientAppRequest(req);
    if (clientMode) {
      if (body?.organization_id && user?.phone) {
        const phone = String(user.phone).replace(/\D/g, '');
        const dto = {
          ...body,
          client_phone: phone,
          client_name: body.client_name ?? user.name ?? 'Клиент',
        };
        return this.orders.create(body.organization_id, dto);
      }
      throw new BadRequestException('Укажите organization_id');
    }
    const orgId = user?.organizationId;
    if (orgId) return this.orders.create(orgId, body);
    if (body?.organization_id && user?.phone) {
      const phone = String(user.phone).replace(/\D/g, '');
      const dto = {
        ...body,
        client_phone: phone,
        client_name: body.client_name ?? user.name ?? 'Клиент',
      };
      return this.orders.create(body.organization_id, dto);
    }
    throw new BadRequestException('Нет активной организации');
  }

  /** Очистить всю историю заказов организации (и отвязать чаты). Только для аккаунта с organizationId. */
  @Post('clear-all')
  async clearAll(@Req() req: { user: { organizationId?: string | null } }) {
    const orgId = (req as any).user?.organizationId;
    if (!orgId) throw new BadRequestException('Доступно только для организации');
    return this.orders.clearAllOrders(orgId);
  }

  @Patch(':id/status')
  async updateStatus(@Param('id') id: string, @Body('status') status: string) {
    return this.orders.updateStatus(id, status);
  }

  @Patch(':id/time')
  async updateTime(
    @Param('id') id: string,
    @Body() body: { planned_start_time?: string; planned_end_time?: string },
  ) {
    const result = await this.orders.updateTime(id, body);
    if (!result) throw new NotFoundException('Order not found');
    return result;
  }

  @Post(':id/assign-master')
  async assignMaster(
    @Param('id') id: string,
    @Body()
    body: {
      master_id?: string | null;
      bay_id?: string | null;
    },
  ) {
    return this.orders.assignMaster(id, body ?? {});
  }

  @Post(':id/cancel')
  async cancel(
    @Param('id') id: string,
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string } },
  ) {
    const user = (req as any).user;
    const orgId = user?.organizationId;
    const clientMode = isClientAppRequest(req);
    let result;
    if (!clientMode && orgId) {
      result = await this.orders.cancel(id, { organizationId: orgId });
    } else {
      const phone = user?.phone ? String(user.phone).replace(/\D/g, '') : '';
      if (!phone) throw new BadRequestException('Нет доступа к отмене заказа');
      result = await this.orders.cancel(id, { clientPhone: phone });
    }
    if (!result) throw new NotFoundException('Заказ не найден или нет прав на отмену');
    return result;
  }

  @Post(':id/approval')
  async approveByClient(
    @Param('id') id: string,
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string } },
    @Body()
    body: {
      approved_item_ids?: string[];
      rejected_item_ids?: string[];
      approval_message_id?: string;
    },
  ) {
    const approvedIds = body?.approved_item_ids ?? [];
    const rejectedIds = body?.rejected_item_ids ?? [];
    const approvalMessageId = body?.approval_message_id;
    console.log('[approval] POST approval', {
      orderId: id,
      approved_item_ids: approvedIds,
      rejected_item_ids: rejectedIds,
      approval_message_id: approvalMessageId ?? null,
    });
    const user = (req as any).user;
    if (!isClientAppRequest(req) && user?.organizationId) {
      throw new BadRequestException('Только клиент может согласовать доп. работы');
    }
    const phone = user?.phone ? String(user.phone).replace(/\D/g, '') : '';
    if (!phone) throw new BadRequestException('Нет номера телефона');
    const order = await this.orders.approveByClient(id, phone, approvedIds, rejectedIds, {
      approvalMessageId,
    });
    if (!order) throw new BadRequestException('Не удалось согласовать. Проверьте, что заказ ожидает согласования и принадлежит вам.');
    return order;
  }

  @Post(':id/confirm')
  async confirmByClient(
    @Param('id') id: string,
    @Req() req: Request & { user: { organizationId?: string | null; phone?: string } },
    @Body() body: { date_time?: string; accept_proposed?: boolean; approval_message_id?: string },
  ) {
    const user = (req as any).user;
    if (!isClientAppRequest(req) && user?.organizationId) {
      throw new BadRequestException('Только клиент может подтвердить заказ');
    }
    const phone = user?.phone ? String(user.phone).replace(/\D/g, '') : '';
    if (!phone) throw new BadRequestException('Нет номера телефона');
    const order = await this.orders.confirmByClient(
      id,
      phone,
      body?.date_time,
      body?.accept_proposed,
      body?.approval_message_id,
    );
    if (!order) throw new BadRequestException('Не удалось подтвердить заказ. Проверьте, что заказ ожидает согласования и принадлежит вам.');
    return order;
  }

  /** Организация подтверждает согласование за клиента («подтвердить по телефону»). Только для заказов в pending_approval. */
  @Post(':id/confirm-by-phone')
  async confirmByPhone(
    @Param('id') id: string,
    @Req() req: { user: { organizationId?: string | null } },
  ) {
    const orgId = (req as any).user?.organizationId;
    if (!orgId) throw new BadRequestException('Доступно только для организации');
    const order = await this.orders.approveBySto(id, orgId);
    if (!order) throw new BadRequestException('Заказ не найден, не в ожидании согласования или не принадлежит вашей организации.');
    console.log('[confirm-by-phone] orderId=' + id + ', newStatus=' + (order as any).status + ', system message sent');
    return order;
  }

  @Patch(':id/items')
  async updateItems(
    @Param('id') id: string,
    @Body('items') items: any[],
    @Req() req: { user: { organizationId?: string | null } },
  ) {
    const organizationId = (req as any).user?.organizationId ?? undefined;
    return this.orders.updateItems(id, items ?? [], organizationId);
  }

  /** Получить или создать чат по заказу. Business: по organizationId; клиент: по phone (заказ должен быть его). */
  @Get(':id/chat')
  async getChatForOrder(@Param('id') id: string, @Req() req: Request & { user: { organizationId?: string | null; phone?: string } }) {
    const user = (req as any).user;
    const orgId = user?.organizationId;
    const phone = user?.phone;
    if (isClientAppRequest(req)) {
      if (phone != null && String(phone).trim() !== '') {
        return this.orders.getChatForOrder(id, { clientPhone: String(phone) });
      }
      throw new BadRequestException('Требуется авторизация клиента');
    }
    if (orgId) return this.orders.getChatForOrder(id, { organizationId: orgId });
    if (phone != null && String(phone).trim() !== '') return this.orders.getChatForOrder(id, { clientPhone: String(phone) });
    throw new BadRequestException('Требуется авторизация организации или клиента');
  }
}
