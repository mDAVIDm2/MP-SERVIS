import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  app.useStaticAssets(join(process.cwd(), 'public'), {
    index: ['index.html'],
  });

  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );
  app.enableCors();

  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');
  const httpServer = app.getHttpAdapter().getHttpServer() as import('http').Server;
  // Node по умолчанию держит keep-alive коротко; клиенты (Dart HttpClient) при reuse сокета иногда
  // получают «Connection closed before full header was received». Увеличиваем таймауты для LAN/dev.
  httpServer.keepAliveTimeout = 65_000;
  httpServer.headersTimeout = 66_000;
  console.log(`MP-Servis API: http://localhost:${port}/api/v1 (listening on 0.0.0.0)`);
}

bootstrap();
