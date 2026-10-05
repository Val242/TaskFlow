import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { DatabaseService } from '../database/database.service';
import { CreateTaskDto } from './dto/create-task.dto';
import { UpdateTaskDto } from './dto/update-task.dto';

@Injectable()
export class TasksService {
  constructor(private readonly databaseService: DatabaseService) {}

  async create(dto: CreateTaskDto) {
    return this.databaseService.task.create({
      data: {
        title: dto.title,
        description: dto.description,
        status: dto.status,
      },
    });
  }

  async findAll() {
    return this.databaseService.task.findMany({
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async findOne(id: string) {
    const task = await this.databaseService.task.findUnique({
      where: { id },
    });

    if (!task) {
      throw new NotFoundException(`Task ${id} was not found`);
    }

    return task;
  }

  async update(id: string, dto: UpdateTaskDto) {
    try {
      return await this.databaseService.task.update({
        where: { id },
        data: {
          title: dto.title,
          description: dto.description,
          status: dto.status,
        },
      });
    } catch (error: unknown) {
      this.handleDatabaseError(error, id);
    }
  }

  async remove(id: string): Promise<void> {
    try {
      await this.databaseService.task.delete({
        where: { id },
      });
    } catch (error: unknown) {
      this.handleDatabaseError(error, id);
    }
  }

  private handleDatabaseError(error: unknown, id: string): never {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2025'
    ) {
      throw new NotFoundException(`Task ${id} was not found`);
    }

    throw error;
  }
}
