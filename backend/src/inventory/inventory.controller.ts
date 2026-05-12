import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Request } from 'express';
import { User } from '../users/user.entity';
import { InventoryService } from './inventory.service';
import { CreateInventoryItemDto } from './dto/create-inventory-item.dto';
import { PatchInventoryItemDto } from './dto/patch-inventory-item.dto';
import { InventoryReceiptDto } from './dto/inventory-receipt.dto';

@Controller('inventory')
@UseGuards(AuthGuard('jwt'))
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

  @Get('items')
  async listItems(
    @Req() req: Request & { user: User },
    @Query('include_inactive') includeInactive?: string,
  ) {
    const { orgId, hidePrices } = this.inventory.assertInventoryAccess(req);
    const inc = includeInactive === '1' || includeInactive === 'true';
    return this.inventory.listItems(orgId, hidePrices, inc);
  }

  @Post('items')
  async createItem(@Req() req: Request & { user: User }, @Body() body: CreateInventoryItemDto) {
    const { orgId, user } = this.inventory.assertInventoryAccess(req);
    return this.inventory.createItem(orgId, user, body);
  }

  @Get('items/:id')
  async getItem(@Req() req: Request & { user: User }, @Param('id') id: string) {
    const { orgId, hidePrices } = this.inventory.assertInventoryAccess(req);
    return this.inventory.getItem(orgId, id, hidePrices);
  }

  @Patch('items/:id')
  async patchItem(@Req() req: Request & { user: User }, @Param('id') id: string, @Body() body: PatchInventoryItemDto) {
    const { orgId, user } = this.inventory.assertInventoryAccess(req);
    return this.inventory.patchItem(orgId, id, user, body);
  }

  @Get('items/:id/movements')
  async itemMovements(
    @Req() req: Request & { user: User },
    @Param('id') id: string,
    @Query('limit') limit?: string,
  ) {
    const { orgId } = this.inventory.assertInventoryAccess(req);
    const lim = limit ? parseInt(limit, 10) : 200;
    return this.inventory.listMovementsForItem(orgId, id, Number.isFinite(lim) ? lim : 200);
  }

  @Post('items/:id/receipt')
  async receipt(@Req() req: Request & { user: User }, @Param('id') id: string, @Body() body: InventoryReceiptDto) {
    const { orgId, user } = this.inventory.assertInventoryAccess(req);
    return this.inventory.receipt(orgId, id, user, body);
  }

  @Get('movements')
  async recentMovements(@Req() req: Request & { user: User }, @Query('limit') limit?: string) {
    const { orgId } = this.inventory.assertInventoryAccess(req);
    const lim = limit ? parseInt(limit, 10) : 150;
    return this.inventory.listRecentMovements(orgId, Number.isFinite(lim) ? lim : 150);
  }
}
