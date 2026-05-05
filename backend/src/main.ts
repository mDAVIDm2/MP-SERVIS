import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import type { CorsOptions } from '@nestjs/common/interfaces/external/cors-options.interface';
import { AppModule } from './app.module';
import { assertProductionSecrets } from './bootstrap-env';

function buildCorsOptions(): CorsOptions {
  const raw = process.env.ALLOWED_ORIGINS?.trim();
  const isProd = process.env.NODE_ENV === 'production';
  const devDefaults = [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    'http://localhost:8080',
    'http://127.0.0.1:8080',
    'http://localhost:5173',
    'http://127.0.0.1:5173',
  ];
  if (isProd) {
    if (!raw) {
      return { origin: false, credentials: false };
    }
    const origins = raw.split(',').map((s) => s.trim()).filter(Boolean);
    return { origin: origins, credentials: false };
  }
  const fromEnv = raw ? raw.split(',').map((s) => s.trim()).filter(Boolean) : [];
  const origin = [...new Set([...devDefaults, ...fromEnv])];
  return { origin, credentials: false };
}

async function bootstrap() {
  assertProductionSecrets();
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
  app.enableCors(buildCorsOptions());

  const port = process.env.PORT || 3000;
  /** За IIS/nginx прокси на этой же машине используйте LISTEN_HOST=127.0.0.1 (не публикуйте порт в интернет). */
  const listenHost = process.env.LISTEN_HOST?.trim() || '0.0.0.0';
  await app.listen(port, listenHost);
  const httpServer = app.getHttpAdapter().getHttpServer() as import('http').Server;
  // Node по умолчанию держит keep-alive коротко; клиенты (Dart HttpClient) при reuse сокета иногда
  // получают «Connection closed before full header was received». Увеличиваем таймауты для LAN/dev.
  httpServer.keepAliveTimeout = 65_000;
  httpServer.headersTimeout = 66_000;
  console.log(`MP-Servis API: http://localhost:${port}/api/v1 (listening on ${listenHost})`);
}

bootstrap();
