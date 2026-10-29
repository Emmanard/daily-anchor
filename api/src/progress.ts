import type { StoredEvent } from './store';

export interface DayProgress {
  /** The device's local calendar day, as YYYY-MM-DD. */
  date: string;
  /** Routines that are done at the end of that day. */
  routinesCompleted: number;
  recallAttempts: number;
}

const MINUTE_MS = 60_000;
const DAY_MS = 24 * 60 * MINUTE_MS;

function localDate(at: Date, utcOffsetMinutes: number): string {
  return new Date(at.getTime() + utcOffsetMinutes * MINUTE_MS)
    .toISOString()
    .slice(0, 10);
}

/** The instant (UTC) at which the oldest day of the range begins. */
export function progressStart(
  now: Date,
  days: number,
  utcOffsetMinutes: number,
): Date {
  const today = localDate(now, utcOffsetMinutes);
  const localMidnight = Date.parse(`${today}T00:00:00.000Z`);
  return new Date(
    localMidnight - utcOffsetMinutes * MINUTE_MS - (days - 1) * DAY_MS,
  );
}

/**
 * One entry per day for the last [days] days, oldest first. A routine counts as
 * done on a day when its latest event that day is a completion, which is how
 * the app shows it, so completing and undoing leaves it not done.
 */
export function buildProgress(
  events: StoredEvent[],
  now: Date,
  days: number,
  utcOffsetMinutes: number,
): DayProgress[] {
  const start = progressStart(now, days, utcOffsetMinutes);
  const result = new Map<string, { done: Set<string>; recall: number }>();
  for (let i = 0; i < days; i++) {
    const date = localDate(new Date(start.getTime() + i * DAY_MS), utcOffsetMinutes);
    result.set(date, { done: new Set(), recall: 0 });
  }

  const ordered = [...events].sort(
    (a, b) => a.occurredAt.getTime() - b.occurredAt.getTime(),
  );
  for (const event of ordered) {
    const day = result.get(localDate(event.occurredAt, utcOffsetMinutes));
    if (!day) continue;

    switch (event.type) {
      case 'routine_completed':
        day.done.add(String(event.payload['routineId']));
        break;
      case 'routine_undone':
        day.done.delete(String(event.payload['routineId']));
        break;
      case 'recall_completed':
        day.recall += 1;
        break;
      case 'feedback_submitted':
        break;
    }
  }

  return [...result].map(([date, day]) => ({
    date,
    routinesCompleted: day.done.size,
    recallAttempts: day.recall,
  }));
}
