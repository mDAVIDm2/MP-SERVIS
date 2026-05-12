import { IsBoolean, IsIn, IsNumber, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class PatchInventoryItemDto {
  @IsOptional()
  @IsString()
  @MaxLength(512)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  unit?: string;

  @IsOptional()
  @IsIn(['part', 'material', 'consumable', 'tool'])
  item_type?: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  category?: string | null;

  @IsOptional()
  @IsString()
  description?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(256)
  brand?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  article?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  sku?: string | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  purchase_price_kopecks?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  sale_price_kopecks?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(1e12)
  min_stock?: number;

  @IsOptional()
  @IsBoolean()
  track_stock?: boolean;

  @IsOptional()
  @IsBoolean()
  allow_fractional?: boolean;

  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}
