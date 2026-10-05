import { TaskStatus } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsString,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

export class CreateTaskDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title!: string;

  @ValidateIf((_object, value: unknown) => value !== undefined)
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ValidateIf((_object, value: unknown) => value !== undefined)
  @IsEnum(TaskStatus)
  status?: TaskStatus;
}
