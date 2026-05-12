import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Response, Request } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';
import { UseInterceptors, UploadedFile } from '@nestjs/common';
import { isClientAppRequest } from '../common/request-app.util';
import { OrderAccessParticipantContext, OrdersService } from './orders.service';

function orderAccessFromRequest(
  req: Request & { user?: { id?: string; organizationId?: string | null; phone?: string | null } },
): OrderAccessParticipantContext {
  const user = (req as Request & { user?: Record<string, unknown> }).user as
    | { id?: string; organizationId?: string | null; phone?: string | null }
    | undefined;
  return {
    userId: user?.id,
    organizationId: user?.organizationId ?? null,
    phoneRaw: user?.phone ?? null,
    isClientApp: isClientAppRequest(req),
  };
}

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
  async getPhotos(@Param('orderId') orderId: string, @Req() req: Request) {
    return this.orders.getOrderPhotos(orderId, orderAccessFromRequest(req));
  }

  @Post(':orderId/photos')
  @UseInterceptors(FileInterceptor('file'))
  async addPhoto(
    @Param('orderId') orderId: string,
    @UploadedFile() file: Express.Multer.File,
    @Req() req: Request & { user?: { id?: string } },
  ) {
    if (!file || !file.buffer) throw new BadRequestException('Файл не передан');
    return this.orders.addOrderPhoto(orderId, file, {
      uploadedByUserId: req.user?.id ?? null,
      access: orderAccessFromRequest(req),
    });
  }

  @Get(':orderId/photos/:photoId/file')
  async getPhotoFile(
    @Param('orderId') orderId: string,
    @Param('photoId') photoId: string,
    @Res() res: Response,
    @Req() req: Request,
  ) {
    const filePath = await this.orders.getOrderPhotoFile(orderId, photoId, orderAccessFromRequest(req));
    if (!filePath) throw new NotFoundException('Not found');
    return res.sendFile(filePath);
  }

  @Post(':id/inventory-lines')
  async addOrderInventoryLine(
    @Param('id') id: string,
    @Body() body: Record<string, unknown>,
    @Req() req: Request & { user?: { organizationId?: string | null } },
  ) {
    const orgId = (req as any).user?.organizationId;
    if (!orgId) throw new BadRequestException('Нет активной организации');
    if (isClientAppRequest(req)) {
      throw new BadRequestException('Добавление материалов к заказу доступно только в приложении для бизнеса');
    }
    return this.orders.addOrderInventoryLine(id, orgId, body ?? {});
  }

  @Get(':id')
  async get(
    @Param('id') id: string,
    @Req() req: Request & { user: { id?: string; organizationId?: string | null; phone?: string } },
  ) {
    const user = (req as any).user;
    const clientMode = isClientAppRequest(req);
    const orgId = user?.organizationId;
    const clientLike = clientMode || (!orgId && user?.phone);
    const o = await this.orders.findOne(id, clientLike && user?.id ? user.id : undefined);
    if (!o) throw new NotFoundException('Order not found');
    const userPhone = user?.phone ? this.orders.normalizePhoneForCompare(user.phone) : '';

    if (clientMode || (!orgId && user?.phone)) {
      const orderPhone = this.orders.normalizePhoneForCompare((o as any).client_phone);
      const phoneOk = !!(userPhone && orderPhone === userPhone);
      const carOk = user?.id
        ? await this.orders.clientCanAccessOrderByOwnedCar(user.id, o as { car_id?: string | null; date_time?: string | null })
        : false;
      if (!phoneOk && !carOk) throw new NotFoundException('Order not found');
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
        return this.orders.create(body.organization_id, dto, 'client');
      }
      throw new BadRequestException('Укажите organization_id');
    }
    const orgId = user?.organizationId;
    if (orgId) return this.orders.create(orgId, body, 'organization');
    if (body?.organization_id && user?.phone) {
      const phone = String(user.phone).replace(/\D/g, '');
      const dto = {
        ...body,
        client_phone: phone,
        client_name: body.client_name ?? user.name ?? 'Клиент',
      };
      return this.orders.create(body.organization_id, dto, 'client');
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
  async updateStatus(
    @Param('id') id: string,
    @Body('status') status: string,
    @Req() req: Request & { user?: { organizationId?: string | null } },
  ) {
    return this.orders.updateStatus(id, status, (req as { user?: { organizationId?: string | null } }).user?.organizationId);
  }

  @Patch(':id/time')
  async updateTime(
    @Param('id') id: string,
    @Body() body: { planned_start_time?: string; planned_end_time?: string },
    @Req() req: Request & { user?: { organizationId?: string | null } },
  ) {
    const result = await this.orders.updateTime(id, body, req.user?.organizationId);
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
    @Req() req: Request & { user?: { organizationId?: string | null } },
  ) {
    return this.orders.assignMaster(id, body ?? {}, req.user?.organizationId);
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
    @Body()
    body: {
      date_time?: string;
      accept_proposed?: boolean;
      approval_message_id?: string;
      approved_item_ids?: string[];
      rejected_item_ids?: string[];
    },
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
      {
        approvedItemIds: body?.approved_item_ids,
        rejectedItemIds: body?.rejected_item_ids,
      },
    );
    if (!order) throw new BadRequestException('Не удалось подтвердить заказ. Проверьте, что заказ ожидает согласования и принадлежит вам.');
    return order;
  }

  /**
   * Business: согласование доп. работ за клиента (pending_approval) ИЛИ подтверждение записи,
   * когда ждут клиента в приложении (pending_confirmation + ответственный client).
   */
  @Post(':id/confirm-by-phone')
  async confirmByPhone(
    @Param('id') id: string,
    @Req() req: { user: { organizationId?: string | null } },
  ) {
    const orgId = (req as any).user?.organizationId;
    if (!orgId) throw new BadRequestException('Доступно только для организации');
    let order = await this.orders.approveBySto(id, orgId);
    if (!order) {
      order = await this.orders.confirmPendingBookingOnBehalfOfClient(id, orgId);
    }
    if (!order) {
      throw new BadRequestException(
        'Заказ не найден, не в ожидании согласования/подтверждения клиентом или не принадлежит вашей организации.',
      );
    }
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
