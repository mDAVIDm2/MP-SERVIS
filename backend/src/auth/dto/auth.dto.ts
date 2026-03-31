import { IsEmail, IsIn, IsOptional, IsString, Length, Matches, IsUUID, ValidateIf } from 'class-validator';

export class SendCodeDto {
  @ValidateIf((o) => !o.phone || String(o.phone).trim() === '')
  @IsEmail()
  email?: string;

  @ValidateIf((o) => !o.email || String(o.email).trim() === '')
  @IsString()
  @Matches(/^[\d\s+()-]{10,24}$/, { message: 'Некорректный телефон' })
  phone?: string;

  @IsOptional()
  @IsString()
  @IsIn(['email', 'sms', 'voice', 'flash', 'console'])
  channel?: string;
}

export class VerifyCodeDto {
  @ValidateIf((o) => !o.phone || String(o.phone).trim() === '')
  @IsEmail()
  email?: string;

  @ValidateIf((o) => !o.email || String(o.email).trim() === '')
  @IsString()
  @Matches(/^[\d\s+()-]{10,24}$/)
  phone?: string;

  @IsUUID('4')
  challenge_id!: string;

  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;

  /** Только при входе по email: сохранить телефон без подтверждения (не выставляет phone_verified_at). */
  @IsOptional()
  @IsString()
  @Length(0, 32)
  phone_unverified?: string;

  @IsOptional()
  @IsString()
  @Length(0, 120)
  name?: string;

  @IsOptional()
  @IsString()
  @Length(0, 128)
  device_id?: string;

  @IsOptional()
  @IsString()
  @Length(0, 256)
  device_name?: string;

  @IsOptional()
  @IsString()
  @Length(0, 32)
  platform?: string;
}

export class RefreshDto {
  @IsString()
  @Length(40, 512)
  refresh_token!: string;

  @IsOptional()
  @IsString()
  @Length(0, 128)
  device_id?: string;

  @IsOptional()
  @IsString()
  @Length(0, 256)
  device_name?: string;

  @IsOptional()
  @IsString()
  @Length(0, 32)
  platform?: string;
}

export class LogoutDto {
  @IsString()
  @Length(40, 512)
  refresh_token!: string;
}
