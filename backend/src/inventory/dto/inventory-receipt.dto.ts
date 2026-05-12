import { Type } from 'class-transformer';
import { IsNumber, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class InventoryReceiptDto {
  @Type(() => Number)
  @IsNumber()
  @Min(0.000001)
  @Max(1e12)
  quantity!: number;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  unit?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  comment?: string;
}
