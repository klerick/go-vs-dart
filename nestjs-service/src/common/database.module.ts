import { Module, DynamicModule } from '@nestjs/common';
import { Pool } from 'pg';

const PG_REPOSITORIES = ['ProductRepository', 'OrderRepository'] as const;

@Module({})
export class DatabaseModule {
  static forRoot(connectionString?: string): DynamicModule {
    const url = connectionString || process.env.POSTGRES_URL || 'postgres://bench:bench@localhost:5432/bench';
    return {
      module: DatabaseModule,
      global: true,
      providers: [
        {
          provide: 'PG_POOL',
          useFactory: () => new Pool({ connectionString: url, max: 10, ssl: false }),
        },
      ],
      exports: ['PG_POOL'],
    };
  }

  static forChild(repositories: string[]): DynamicModule {
    const providers = repositories.map((repo) => ({
      provide: repo,
      useFactory: (pool: Pool) => ({ pool, name: repo }),
      inject: ['PG_POOL'],
    }));
    return {
      module: DatabaseModule,
      providers,
      exports: repositories,
    };
  }
}
