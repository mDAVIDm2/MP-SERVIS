import { Body, Controller, Delete, Get, Param, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { NotificationsService } from './notifications.service';

function respectClientNotificationPrefs(req: { headers?: Record<string, string | string[] | undefined> }): boolean {
  const h = req.headers?.['x-mp-servis-app'] ?? req.headers?.['X-MP-Servis-App'];
  const v = Array.isArray(h) ? h[0] : h;
  return String(v || '').toLowerCase() === 'client';
}

@Controller('notifications')
@UseGuards(AuthGuard('jwt'))
export class NotificationsController {
  constructor(private notifications: NotificationsService) {}

  @Post('register-device')
  async registerDevice(
    @Req() req: { user: { id: string } },
    @Body() body: { device_token: string; platform?: string; fcm_app?: string },
  ) {
    const raw = (body.fcm_app ?? '').toLowerCase();
    const fcmApp = raw === 'business' ? ('business' as const) : ('client' as const);
    await this.notifications.registerDevice(
      (req as any).user.id,
      body.device_token,
      body.platform || 'android',
      fcmApp,
    );
    return {};
  }

  @Get()
  async list(@Req() req: { user: { id: string }; headers?: any }, @Query('car_id') carId?: string) {
    const respect = respectClientNotificationPrefs(req);
    return this.notifications.getNotifications((req as any).user.id, carId ?? undefined, respect);
  }

  @Get('unread-count')
  async unreadCount(@Req() req: { user: { id: string }; headers?: any }) {
    const respect = respectClientNotificationPrefs(req);
    const count = await this.notifications.getUnreadCount((req as any).user.id, respect);
    return { count };
  }

  @Get('unread-by-car')
  async unreadByCar(@Req() req: { user: { id: string }; headers?: any }) {
    const respect = respectClientNotificationPrefs(req);
    return this.notifications.getUnreadCountPerCar((req as any).user.id, respect);
  }

  @Post('mark-all-read')
  async markAllRead(@Req() req: { user: { id: string } }, @Body() body: { car_id?: string }) {
    await this.notifications.markAllAsRead((req as any).user.id, body.car_id);
    return { success: true };
  }

  @Post('mark-read-by-order')
  async markReadByOrder(@Req() req: { user: { id: string } }, @Body() body: { order_id?: string }) {
    const oid = body?.order_id?.trim();
    if (oid) await this.notifications.markUnreadAsReadByOrderId((req as any).user.id, oid);
    return { success: true };
  }

  @Post('mark-read-by-chat')
  async markReadByChat(@Req() req: { user: { id: string } }, @Body() body: { chat_id?: string }) {
    const cid = body?.chat_id?.trim();
    if (cid) await this.notifications.markUnreadAsReadByChatId((req as any).user.id, cid);
    return { success: true };
  }

  @Post(':id/read')
  async markAsRead(@Req() req: { user: { id: string } }, @Param('id') id: string) {
    await this.notifications.markAsRead((req as any).user.id, id);
    return { success: true };
  }

  @Delete(':id')
  async delete(@Req() req: { user: { id: string } }, @Param('id') id: string) {
    await this.notifications.delete((req as any).user.id, id);
    return { success: true };
  }
}
