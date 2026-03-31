import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class PatchServiceCatalogSuggestionDto {
  @IsIn(['pending', 'reviewed'])
  status: 'pending' | 'reviewed';

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  review_note?: string | null;
}
