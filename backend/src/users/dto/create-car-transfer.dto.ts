import { IsObject, IsOptional, IsString, MinLength } from 'class-validator';

/** Тело POST /profile/car-transfers (class-validator + whitelist в main.ts). */
export class CreateCarTransferDto {
  @IsString()
  @MinLength(1)
  car_id: string;

  @IsString()
  @MinLength(10)
  to_phone: string;

  @IsOptional()
  @IsObject()
  options?: Record<string, unknown>;
}
