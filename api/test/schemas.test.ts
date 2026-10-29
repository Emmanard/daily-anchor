import { randomUUID } from 'node:crypto';

import { describe, expect, it } from 'vitest';

import { parseEvent } from '../src/schemas';

const NOW = new Date('2026-10-28T12:00:00.000Z');

function event(overrides: Record<string, unknown> = {}) {
  return {
    id: randomUUID(),
    type: 'routine_completed',
    payload: { routineId: 'morning-water' },
    occurredAt: '2026-10-28T09:00:00.000Z',
    ...overrides,
  };
}

function reasonOf(raw: unknown): string {
  const result = parseEvent(raw, NOW);
  if (result.ok) throw new Error('expected the event to be rejected');
  return result.reason;
}

describe('parseEvent', () => {
  it('accepts each event type', () => {
    const valid = [
      event(),
      event({ type: 'routine_undone' }),
      event({
        type: 'recall_completed',
        payload: { correctCount: 4, durationMs: 9000 },
      }),
      event({
        type: 'feedback_submitted',
        payload: { message: 'Bigger buttons please' },
      }),
    ];

    for (const raw of valid) {
      expect(parseEvent(raw, NOW).ok).toBe(true);
    }
  });

  it('accepts microsecond timestamps like the app sends', () => {
    const result = parseEvent(
      event({ occurredAt: '2026-10-28T09:00:00.123456Z' }),
      NOW,
    );

    expect(result.ok).toBe(true);
  });

  it('converts occurredAt to a Date', () => {
    const result = parseEvent(event(), NOW);

    expect(result.ok && result.event.occurredAt.toISOString()).toBe(
      '2026-10-28T09:00:00.000Z',
    );
  });

  it('rejects an id that is not a UUID', () => {
    expect(reasonOf(event({ id: 'not-a-uuid' }))).toContain('id');
  });

  it('rejects an unknown type', () => {
    expect(reasonOf(event({ type: 'something_else' }))).toContain('type');
  });

  it('rejects a timestamp that is not ISO 8601 in UTC', () => {
    expect(reasonOf(event({ occurredAt: 'yesterday' }))).toContain('occurredAt');
    expect(reasonOf(event({ occurredAt: '2026-10-28T09:00:00+02:00' }))).toContain(
      'occurredAt',
    );
  });

  it('rejects a missing or wrong payload', () => {
    expect(reasonOf(event({ payload: undefined }))).toContain('payload');
    expect(reasonOf(event({ payload: {} }))).toContain('payload.routineId');
    expect(
      reasonOf(
        event({
          type: 'recall_completed',
          payload: { correctCount: 6, durationMs: 1000 },
        }),
      ),
    ).toContain('payload.correctCount');
    expect(
      reasonOf(
        event({
          type: 'recall_completed',
          payload: { correctCount: 3, durationMs: -1 },
        }),
      ),
    ).toContain('payload.durationMs');
  });

  it('rejects empty and over-long feedback', () => {
    const feedback = (message: string) =>
      event({ type: 'feedback_submitted', payload: { message } });

    expect(reasonOf(feedback('   '))).toContain('payload.message');
    expect(reasonOf(feedback('x'.repeat(501)))).toContain('payload.message');
  });

  it('rejects things that are not objects', () => {
    expect(parseEvent(null, NOW).ok).toBe(false);
    expect(parseEvent('text', NOW).ok).toBe(false);
    expect(parseEvent(42, NOW).ok).toBe(false);
  });

  it('allows a small clock drift but not a far-future event', () => {
    const soon = parseEvent(event({ occurredAt: '2026-10-29T11:00:00.000Z' }), NOW);
    const far = parseEvent(event({ occurredAt: '2026-11-05T12:00:00.000Z' }), NOW);

    expect(soon.ok).toBe(true);
    expect(far.ok).toBe(false);
    expect(!far.ok && far.reason).toBe('occurredAt: too_far_in_future');
  });

  it('drops payload keys it does not know, so they are never stored', () => {
    const result = parseEvent(
      event({ payload: { routineId: 'a', extra: 'kept?' } }),
      NOW,
    );

    expect(result.ok && result.event.payload).toEqual({ routineId: 'a' });
  });

  it('trims feedback text', () => {
    const result = parseEvent(
      event({ type: 'feedback_submitted', payload: { message: '  hello  ' } }),
      NOW,
    );

    expect(result.ok && result.event.payload).toEqual({ message: 'hello' });
  });

  it('never repeats the submitted text in a rejection reason', () => {
    const secret = 'PRIVATE-TEXT-' + 'x'.repeat(600);

    const reason = reasonOf(
      event({ type: 'feedback_submitted', payload: { message: secret } }),
    );

    expect(reason).not.toContain('PRIVATE-TEXT');
  });
});
