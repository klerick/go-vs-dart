import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from './app.module';

async function bootstrap() {
  const port = parseInt(process.env.HTTP_PORT || '8080');
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter(),
    { logger: ['warn', 'error'] },
  );
  await app.listen(port, '0.0.0.0');
  console.log(`Server listening on port ${port}`);
}
bootstrap();
