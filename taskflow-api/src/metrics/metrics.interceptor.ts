import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Observable, tap } from 'rxjs';
import { MetricsService } from './metrics.service';

@Injectable()
export class MetricsInterceptor implements NestInterceptor {
  constructor(private readonly metricsService: MetricsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest<Request>();
    const response = context.switchToHttp().getResponse<Response>();

    const start = process.hrtime.bigint();

    return next.handle().pipe(
      tap(() => {
        const duration =
          Number(process.hrtime.bigint() - start) / 1_000_000_000;

        const route = request.route?.path ?? request.path;

        this.metricsService.incrementRequest(
          request.method,
          route,
          response.statusCode,
        );

        this.metricsService.observeRequestDuration(
          request.method,
          route,
          response.statusCode,
          duration,
        );
      }),
    );
  }
}
