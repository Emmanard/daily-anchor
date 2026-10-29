import { createApp } from './app';
import { loadConfig } from './config';
import { createPrismaClient } from './db';
import { PrismaEventStore } from './prisma-store';

const config = loadConfig();
const prisma = createPrismaClient(config.DATABASE_URL);
const app = createApp({ store: new PrismaEventStore(prisma) });

const server = app.listen(config.PORT, () => {
  console.log(`Daily Anchor API listening on port ${config.PORT}`);
});

async function shutdown() {
  server.close();
  await prisma.$disconnect();
}

process.on('SIGTERM', () => void shutdown());
process.on('SIGINT', () => void shutdown());
