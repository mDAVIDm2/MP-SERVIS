import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

/** Поля ручной записи (camelCase как у Flutter). */
export class UpsertManualExpenseDto {
  @IsDateString()
  date!: string;

  @IsString()
  @Length(1, 40)
  kind!: string;

  @IsInt()
  @Min(0)
  priceKopecks!: number;

  @IsOptional()
  @IsString()
  @Length(0, 40)
  fuelType?: string | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  fuelLiters?: number | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  fuelPricePerLiterKopecks?: number | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  odometerKm?: number | null;

  @IsOptional()
  @IsString()
  @Length(0, 200)
  fuelStationName?: string | null;

  @IsOptional()
  @IsBoolean()
  fullTank?: boolean | null;

  @IsOptional()
  @IsString()
  @Length(0, 100)
  presetId?: string | null;

  @IsOptional()
  @IsString()
  @Length(0, 200)
  customTitle?: string | null;

  @IsOptional()
  @IsString()
  @Length(0, 2000)
  note?: string | null;

  @IsOptional()
  @IsString()
  @Length(0, 100)
  expenseGroupId?: string | null;

  @IsOptional()
  @IsString()
  @Length(0, 100)
  expenseSubId?: string | null;

  @IsOptional()
  @IsString()
  @Length(0, 100)
  expenseCategoryId?: string | null;

  @IsOptional()
  @IsString()
  @Length(0, 200)
  expenseItemTitle?: string | null;

  @IsOptional()
  @IsString()
  @Length(0, 100)
  analyticsOperationName?: string | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  materialPriceKopecks?: number | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  laborPriceKopecks?: number | null;

  @IsOptional()
  @IsString()
  @Length(0, 200)
  placeName?: string | null;

  @IsOptional()
  @IsDateString()
  clientUpdatedAt?: string | null;

  @IsOptional()
  @IsString()
  @Length(0, 128)
  deviceId?: string | null;
}

export class SyncDeleteItemDto {
  @IsString()
  @Length(1, 120)
  clientRecordId!: string;

  @IsOptional()
  @IsDateString()
  clientUpdatedAt?: string | null;
}

/** Элемент bulk-sync: clientRecordId + поля записи. */
export class SyncUpsertItemDto extends UpsertManualExpenseDto {
  @IsString()
  @Length(1, 120)
  clientRecordId!: string;
}

export class SyncChangesDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncUpsertItemDto)
  upserts!: SyncUpsertItemDto[];

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncDeleteItemDto)
  deletes!: SyncDeleteItemDto[];
}

export class SyncManualExpensesDto {
  @IsOptional()
  @IsDateString()
  lastPulledAt?: string | null;

  /** Если не передан — на сервере считается пустым пакетом (только pull). */
  @IsOptional()
  @ValidateNested()
  @Type(() => SyncChangesDto)
  changes?: SyncChangesDto;
}

export class ListManualExpensesQueryDto {
  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;

  @IsOptional()
  @IsDateString()
  updatedSince?: string;

  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true' || value === '1')
  @IsBoolean()
  includeDeleted?: boolean;

  @IsOptional()
  @IsString()
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(500)
  limit?: number;
}
