import { randomUUID } from 'node:crypto';

import request from 'supertest';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { createApp } from '../src/app';
import { MAX_BATCH_SIZE } from '../src/schemas';
import { InMemoryEventStore } from './support/in-memory-store';

const NOW = new Date('2026-10-28T12:00:00.000Z');
const DEVICE = randomUUID();

function routineEvent(overrides: Record<string, unknown> = {}) {
  return {
    id: randomUUID(),
    type: 'routine_completed',
    payload: { routineId: 'morning-water' },
    occurredAt: '2026-10-28T09:00:00.000Z',
    ...overrides,
  };
}

let store: InMemoryEventStore;
let app: ReturnType<typeof createApp>;

beforeEach(() => {
  store = new InMemoryEventStore();
  app = createApp({ store, now: () => NOW });
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('GET /health', () => {
  it('reports ok', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('does not advertise the framework', async () => {
    const res = await request(app).get('/health');

    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

describe('POST /events', () => {
  it('stores new events and reports them as accepted', async () => {
    const events = [routineEvent(), routineEvent({ type: 'routine_undone' })];

    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      accepted: events.map((e) => e.id),
      duplicates: [],
      rejected: [],
    });
    expect(store.rows).toHaveLength(2);
    expect(store.rows.every((row) => row.deviceId === DEVICE)).toBe(true);
  });

  it('does not store an event twice when a batch is sent again', async () => {
    const events = [routineEvent(), routineEvent()];
    const body = { deviceId: DEVICE, events };

    await request(app).post('/events').send(body);
    const retry = await request(app).post('/events').send(body);

    expect(retry.status).toBe(200);
    expect(retry.body.accepted).toEqual([]);
    expect(retry.body.duplicates).toEqual(events.map((e) => e.id));
    expect(store.rows).toHaveLength(2);
  });

  it('accepts new events and reports old ones as duplicates in one batch', async () => {
    const first = routineEvent();
    const second = routineEvent();
    await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events: [first] });

    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events: [first, second] });

    expect(res.body.accepted).toEqual([second.id]);
    expect(res.body.duplicates).toEqual([first.id]);
    expect(store.rows).toHaveLength(2);
  });

  it('keeps the first of an id repeated inside one batch', async () => {
    const event = routineEvent();

    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events: [event, event] });

    expect(res.body.accepted).toEqual([event.id]);
    expect(res.body.duplicates).toEqual([event.id]);
    expect(store.rows).toHaveLength(1);
  });

  it('rejects a malformed event without failing the rest of the batch', async () => {
    const good = routineEvent();
    const badType = routineEvent({ type: 'something_else' });
    const noId = { type: 'routine_completed', payload: {}, occurredAt: 'nope' };

    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events: [badType, good, noId, 'text'] });

    expect(res.status).toBe(200);
    expect(res.body.accepted).toEqual([good.id]);
    expect(res.body.rejected).toHaveLength(3);
    expect(res.body.rejected[0]).toMatchObject({ index: 0, id: badType.id });
    expect(res.body.rejected[1]).toMatchObject({ index: 2, id: null });
    expect(res.body.rejected[2]).toMatchObject({ index: 3, id: null });
    expect(typeof res.body.rejected[0].reason).toBe('string');
    expect(store.rows.map((row) => row.id)).toEqual([good.id]);
  });

  it('refuses a batch above the size limit and stores nothing', async () => {
    const events = Array.from({ length: MAX_BATCH_SIZE + 1 }, () =>
      routineEvent(),
    );

    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events });

    expect(res.status).toBe(413);
    expect(res.body.error.code).toBe('batch_too_large');
    expect(store.rows).toHaveLength(0);
  });

  it('accepts a batch of exactly the size limit', async () => {
    const events = Array.from({ length: MAX_BATCH_SIZE }, () => routineEvent());

    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events });

    expect(res.status).toBe(200);
    expect(res.body.accepted).toHaveLength(MAX_BATCH_SIZE);
  });

  it('accepts an empty batch', async () => {
    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events: [] });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ accepted: [], duplicates: [], rejected: [] });
  });

  it.each([
    ['a missing device id', { events: [] }],
    ['a device id that is not a UUID', { deviceId: 'abc', events: [] }],
    ['events that are not a list', { deviceId: DEVICE, events: 'nope' }],
    ['no events field', { deviceId: DEVICE }],
  ])('rejects %s', async (_name, body) => {
    const res = await request(app).post('/events').send(body);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('invalid_request');
  });

  it('rejects a request with no body', async () => {
    const res = await request(app).post('/events');

    expect(res.status).toBe(400);
  });

  it('rejects a body that is not valid JSON', async () => {
    const res = await request(app)
      .post('/events')
      .set('Content-Type', 'application/json')
      .send('{"deviceId": ');

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('invalid_json');
  });

  it('rejects a body that is too large', async () => {
    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events: [], padding: 'x'.repeat(600_000) });

    expect(res.status).toBe(413);
    expect(res.body.error.code).toBe('payload_too_large');
  });

  it('does not leak details when the store fails', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    store.failInsert = true;

    const res = await request(app)
      .post('/events')
      .send({ deviceId: DEVICE, events: [routineEvent()] });

    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('internal_error');
    expect(JSON.stringify(res.body)).not.toContain('database unavailable');
  });
});

describe('GET /progress', () => {
  async function send(events: unknown[], deviceId = DEVICE) {
    await request(app).post('/events').send({ deviceId, events });
  }

  it('returns seven zeroed days for a device with no events', async () => {
    const res = await request(app).get('/progress').query({ deviceId: DEVICE });

    expect(res.status).toBe(200);
    expect(res.body.deviceId).toBe(DEVICE);
    expect(res.body.days).toHaveLength(7);
    expect(res.body.days.at(-1)).toEqual({
      date: '2026-10-28',
      routinesCompleted: 0,
      recallAttempts: 0,
    });
  });

  it('summarises the uploaded events by day', async () => {
    await send([
      routineEvent({ payload: { routineId: 'a' } }),
      routineEvent({ payload: { routineId: 'b' } }),
      routineEvent({
        type: 'recall_completed',
        payload: { correctCount: 4, durationMs: 9000 },
      }),
      routineEvent({
        payload: { routineId: 'c' },
        occurredAt: '2026-10-27T10:00:00.000Z',
      }),
    ]);

    const res = await request(app).get('/progress').query({ deviceId: DEVICE });

    expect(res.body.days.at(-1)).toEqual({
      date: '2026-10-28',
      routinesCompleted: 2,
      recallAttempts: 1,
    });
    expect(res.body.days.at(-2).routinesCompleted).toBe(1);
  });

  it('does not show one device the events of another', async () => {
    await send([routineEvent()], randomUUID());

    const res = await request(app).get('/progress').query({ deviceId: DEVICE });

    expect(res.body.days.every((d: { routinesCompleted: number }) => d.routinesCompleted === 0)).toBe(true);
  });

  it('honours the days and utcOffsetMinutes parameters', async () => {
    const res = await request(app)
      .get('/progress')
      .query({ deviceId: DEVICE, days: 3, utcOffsetMinutes: 720 });

    expect(res.status).toBe(200);
    expect(res.body.days.map((d: { date: string }) => d.date)).toEqual([
      '2026-10-27',
      '2026-10-28',
      '2026-10-29',
    ]);
  });

  it.each([
    ['a missing device id', {}],
    ['a device id that is not a UUID', { deviceId: 'abc' }],
    ['zero days', { deviceId: DEVICE, days: 0 }],
    ['too many days', { deviceId: DEVICE, days: 91 }],
    ['a days value that is not a number', { deviceId: DEVICE, days: 'many' }],
    ['an offset out of range', { deviceId: DEVICE, utcOffsetMinutes: 5000 }],
  ])('rejects %s', async (_name, query) => {
    const res = await request(app).get('/progress').query(query);

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('invalid_request');
  });
});

describe('unknown routes', () => {
  it('return a JSON 404', async () => {
    const res = await request(app).get('/nothing-here');

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('not_found');
  });
});
