import { describe, expect, it } from 'vitest';

import { buildProgress, progressStart } from '../src/progress';
import type { StoredEvent } from '../src/store';
import type { EventType } from '../src/schemas';

const NOW = new Date('2026-10-28T12:00:00.000Z');
let counter = 0;

function stored(
  type: EventType,
  at: string,
  payload: Record<string, unknown> = {},
): StoredEvent {
  counter += 1;
  return {
    id: `id-${counter}`,
    deviceId: 'device',
    type,
    payload,
    occurredAt: new Date(at),
    receivedAt: new Date(at),
  };
}

const done = (routineId: string, at: string) =>
  stored('routine_completed', at, { routineId });
const undone = (routineId: string, at: string) =>
  stored('routine_undone', at, { routineId });

describe('buildProgress', () => {
  it('returns one entry per day, oldest first, with zeros when empty', () => {
    const days = buildProgress([], NOW, 7, 0);

    expect(days.map((d) => d.date)).toEqual([
      '2026-10-22',
      '2026-10-23',
      '2026-10-24',
      '2026-10-25',
      '2026-10-26',
      '2026-10-27',
      '2026-10-28',
    ]);
    expect(days.every((d) => d.routinesCompleted === 0 && d.recallAttempts === 0)).toBe(
      true,
    );
  });

  it('counts each routine done at most once a day', () => {
    const days = buildProgress(
      [
        done('a', '2026-10-28T08:00:00Z'),
        done('a', '2026-10-28T09:00:00Z'),
        done('b', '2026-10-28T10:00:00Z'),
      ],
      NOW,
      7,
      0,
    );

    expect(days.at(-1)?.routinesCompleted).toBe(2);
  });

  it('treats an undo as not done, and a later completion as done again', () => {
    const undoneDay = buildProgress(
      [done('a', '2026-10-28T08:00:00Z'), undone('a', '2026-10-28T08:05:00Z')],
      NOW,
      7,
      0,
    );
    const redoneDay = buildProgress(
      [
        done('a', '2026-10-28T08:00:00Z'),
        undone('a', '2026-10-28T08:05:00Z'),
        done('a', '2026-10-28T08:10:00Z'),
      ],
      NOW,
      7,
      0,
    );

    expect(undoneDay.at(-1)?.routinesCompleted).toBe(0);
    expect(redoneDay.at(-1)?.routinesCompleted).toBe(1);
  });

  it('does not depend on the order events are given in', () => {
    const days = buildProgress(
      [undone('a', '2026-10-28T08:05:00Z'), done('a', '2026-10-28T08:00:00Z')],
      NOW,
      7,
      0,
    );

    expect(days.at(-1)?.routinesCompleted).toBe(0);
  });

  it('keeps days separate', () => {
    const days = buildProgress(
      [done('a', '2026-10-27T08:00:00Z'), done('b', '2026-10-28T08:00:00Z')],
      NOW,
      7,
      0,
    );

    expect(days.at(-2)?.routinesCompleted).toBe(1);
    expect(days.at(-1)?.routinesCompleted).toBe(1);
  });

  it('counts word exercises and ignores feedback', () => {
    const days = buildProgress(
      [
        stored('recall_completed', '2026-10-28T08:00:00Z', {
          correctCount: 4,
          durationMs: 9000,
        }),
        stored('recall_completed', '2026-10-28T09:00:00Z', {
          correctCount: 5,
          durationMs: 7000,
        }),
        stored('feedback_submitted', '2026-10-28T09:30:00Z', { message: 'hi' }),
      ],
      NOW,
      7,
      0,
    );

    expect(days.at(-1)?.recallAttempts).toBe(2);
    expect(days.at(-1)?.routinesCompleted).toBe(0);
  });

  it('ignores events outside the range', () => {
    const days = buildProgress(
      [done('a', '2026-10-01T08:00:00Z'), done('b', '2026-10-29T08:00:00Z')],
      NOW,
      7,
      0,
    );

    expect(days.every((d) => d.routinesCompleted === 0)).toBe(true);
  });

  it('uses the device day when given a positive UTC offset', () => {
    const late = new Date('2026-10-28T23:45:00Z');
    const event = done('a', '2026-10-28T23:30:00Z');

    const utc = buildProgress([event], late, 2, 0);
    const plusOne = buildProgress([event], late, 2, 60);

    expect(utc.map((d) => d.date)).toEqual(['2026-10-27', '2026-10-28']);
    expect(utc.at(-1)?.routinesCompleted).toBe(1);
    expect(plusOne.map((d) => d.date)).toEqual(['2026-10-28', '2026-10-29']);
    expect(plusOne.at(-1)?.routinesCompleted).toBe(1);
    expect(plusOne.at(-2)?.routinesCompleted).toBe(0);
  });

  it('uses the device day when given a negative UTC offset', () => {
    const days = buildProgress([done('a', '2026-10-28T03:00:00Z')], NOW, 3, -300);

    expect(days.find((d) => d.date === '2026-10-27')?.routinesCompleted).toBe(1);
    expect(days.find((d) => d.date === '2026-10-28')?.routinesCompleted).toBe(0);
  });

  it('can cover a single day', () => {
    const days = buildProgress([done('a', '2026-10-28T08:00:00Z')], NOW, 1, 0);

    expect(days).toEqual([
      { date: '2026-10-28', routinesCompleted: 1, recallAttempts: 0 },
    ]);
  });
});

describe('progressStart', () => {
  it('is the start of the oldest day in UTC', () => {
    expect(progressStart(NOW, 7, 0).toISOString()).toBe('2026-10-22T00:00:00.000Z');
  });

  it('follows the device day boundary', () => {
    expect(progressStart(NOW, 7, 60).toISOString()).toBe('2026-10-21T23:00:00.000Z');
  });

  it('is the start of today for a one day range', () => {
    expect(progressStart(NOW, 1, 0).toISOString()).toBe('2026-10-28T00:00:00.000Z');
  });
});
