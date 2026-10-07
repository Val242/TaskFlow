import { Controller, Get, Header, Res } from '@nestjs/common';
import type { Response } from 'express';
import { MetricsService } from './metrics.service';

@Controller('metrics')
export class MetricsController {
  constructor(private readonly metricsService: MetricsService) {}

  @Get()
  @Header('Cache-Control', 'no-store')
  async getMetrics(@Res() response: Response) {
    response.setHeader('Content-Type', this.metricsService.getContentType());

    response.send(await this.metricsService.getMetrics());
  }
}
