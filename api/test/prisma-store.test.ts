import { randomUUID } from 'node:crypto';

import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { createApp } from '../src/app';
import { createPrismaClient } from '../src/db';
import { PrismaEventStore } from '../src/prisma-store';
import type { NewEvent } from '../src/store';

// These tests need a real PostgreSQL database that already has the migrations
// applied. They delete every event, so they only ever use TEST_DATABASE_URL and
// never DATABASE_URL.
const testDatabaseUrl = process.env['TEST_DATABASE_URL'];

function newEvent(overrides: Partial<NewEvent> = {}): NewEvent {
  return {
    id: randomUUID(),
    deviceId: randomUUID(),
    type: 'routine_completed',
    payload: { routineId: 'morning-water' },
    occurredAt: new Date('2026-10-28T09:00:00.000Z'),
    ...overrides,
  };
}

describe.skipIf(!testDatabaseUrl)('PrismaEventStore on PostgreSQL', () => {
  const prisma = createPrismaClient(testDatabaseUrl ?? 'postgresql://unused');
  const store = new PrismaEventStore(prisma);

  beforeAll(async () => {
    await prisma.$connect();
  });

  beforeEach(async () => {
    await prisma.event.deleteMany();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('stores an event with its payload and a server receive time', async () => {
    const event = newEvent({
      type: 'recall_completed',
      payload: { correctCount: 4, durationMs: 9000 },
    });

    const inserted = await store.insertNew([event]);
    const found = await store.forDevice(
      event.deviceId,
      new Date('2026-10-28T00:00:00.000Z'),
    );

    expect(inserted).toEqual([event.id]);
    expect(found).toHaveLength(1);
    expect(found[0]?.type).toBe('recall_completed');
    expect(found[0]?.payload).toEqual({ correctCount: 4, durationMs: 9000 });
    expect(found[0]?.occurredAt).toEqual(event.occurredAt);
    expect(found[0]?.receivedAt.getTime()).toBeGreaterThan(0);
  });

  it('skips an event that already exists and does not change it', async () => {
    const original = newEvent({ payload: { routineId: 'original' } });
    await store.insertNew([original]);

    const inserted = await store.insertNew([
      { ...original, payload: { routineId: 'changed' } },
    ]);

    expect(inserted).toEqual([]);
    expect(await prisma.event.count()).toBe(1);
    const row = await prisma.event.findUniqueOrThrow({
      where: { id: original.id },
    });
    expect(row.payload).toEqual({ routineId: 'original' });
  });

  it('returns only the ids it inserted when a batch mixes new and old', async () => {
    const old = newEvent();
    const fresh = newEvent();
    await store.insertNew([old]);

    const inserted = await store.insertNew([old, fresh]);

    expect(inserted).toEqual([fresh.id]);
    expect(await prisma.event.count()).toBe(2);
  });

  it('stores an id once when two requests send it at the same time', async () => {
    const event = newEvent();

    const results = await Promise.all([
      store.insertNew([event]),
      store.insertNew([event]),
      store.insertNew([event]),
    ]);

    expect(results.flat()).toEqual([event.id]);
    expect(await prisma.event.count()).toBe(1);
  });

  it('inserts nothing for an empty list', async () => {
    expect(await store.insertNew([])).toEqual([]);
  });

  it('returns only one device events, from the given time, oldest first', async () => {
    const deviceId = randomUUID();
    await store.insertNew([
      newEvent({ deviceId, occurredAt: new Date('2026-10-28T12:00:00Z') }),
      newEvent({ deviceId, occurredAt: new Date('2026-10-27T12:00:00Z') }),
      newEvent({ deviceId, occurredAt: new Date('2026-10-20T12:00:00Z') }),
      newEvent({ occurredAt: new Date('2026-10-28T10:00:00Z') }),
    ]);

    const found = await store.forDevice(
      deviceId,
      new Date('2026-10-27T00:00:00Z'),
    );

    expect(found.map((e) => e.occurredAt.toISOString())).toEqual([
      '2026-10-27T12:00:00.000Z',
      '2026-10-28T12:00:00.000Z',
    ]);
  });

  it('delivers a batch exactly once through the HTTP API, even when retried', async () => {
    const app = createApp({
      store,
      now: () => new Date('2026-10-28T12:00:00.000Z'),
    });
    const deviceId = randomUUID();
    const events = [
      {
        id: randomUUID(),
        type: 'routine_completed',
        payload: { routineId: 'morning-water' },
        occurredAt: '2026-10-28T09:00:00.000Z',
      },
      {
        id: randomUUID(),
        type: 'feedback_submitted',
        payload: { message: 'Bigger buttons please' },
        occurredAt: '2026-10-28T09:05:00.000Z',
      },
    ];
    const body = { deviceId, events };

    const [first, second] = await Promise.all([
      request(app).post('/events').send(body),
      request(app).post('/events').send(body),
    ]);
    const third = await request(app).post('/events').send(body);

    const acceptedCount =
      first.body.accepted.length + second.body.accepted.length;
    expect(acceptedCount).toBe(2);
    expect(third.body.accepted).toEqual([]);
    expect(third.body.duplicates).toHaveLength(2);
    expect(await prisma.event.count()).toBe(2);

    const progress = await request(app).get('/progress').query({ deviceId });
    expect(progress.body.days.at(-1).routinesCompleted).toBe(1);
  });
});
