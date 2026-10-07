import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class HealthService {
  constructor(private readonly databaseService: DatabaseService) {}

  getLiveness() {
    return {
      status: 'ok',
    };
  }

  async getReadiness() {
    try {
      await this.databaseService.$queryRaw`SELECT 1`;

      return {
        status: 'ok',
        database: 'up',
      };
    } catch {
      return {
        status: 'error',
        database: 'down',
      };
    }
  }
}
