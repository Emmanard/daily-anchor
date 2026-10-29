import type { Prisma, PrismaClient } from '../generated/prisma/client';
import type { EventStore, NewEvent, StoredEvent } from './store';

export class PrismaEventStore implements EventStore {
  constructor(private readonly prisma: PrismaClient) {}

  async insertNew(events: NewEvent[]): Promise<string[]> {
    if (events.length === 0) return [];

    // The primary key decides which events are new. Rows that already exist are
    // skipped and are not returned, so even two requests sending the same id at
    // once store it once.
    const created = await this.prisma.event.createManyAndReturn({
      data: events.map((event) => ({
        id: event.id,
        deviceId: event.deviceId,
        type: event.type,
        payload: event.payload as Prisma.InputJsonObject,
        occurredAt: event.occurredAt,
      })),
      skipDuplicates: true,
      select: { id: true },
    });
    return created.map((row) => row.id);
  }

  async forDevice(deviceId: string, since: Date): Promise<StoredEvent[]> {
    const rows = await this.prisma.event.findMany({
      where: { deviceId, occurredAt: { gte: since } },
      orderBy: [{ occurredAt: 'asc' }, { receivedAt: 'asc' }, { id: 'asc' }],
    });
    return rows.map((row) => ({
      id: row.id,
      deviceId: row.deviceId,
      type: row.type,
      payload: row.payload as Record<string, unknown>,
      occurredAt: row.occurredAt,
      receivedAt: row.receivedAt,
    }));
  }
}
