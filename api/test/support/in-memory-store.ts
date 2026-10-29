import type { EventStore, NewEvent, StoredEvent } from '../../src/store';

/** Mimics the database rule that an event id can be stored only once. */
export class InMemoryEventStore implements EventStore {
  readonly rows: StoredEvent[] = [];
  failInsert = false;

  async insertNew(events: NewEvent[]): Promise<string[]> {
    if (this.failInsert) throw new Error('database unavailable');
    const inserted: string[] = [];
    for (const event of events) {
      if (this.rows.some((row) => row.id === event.id)) continue;
      this.rows.push({ ...event, receivedAt: new Date() });
      inserted.push(event.id);
    }
    return inserted;
  }

  async forDevice(deviceId: string, since: Date): Promise<StoredEvent[]> {
    return this.rows
      .filter(
        (row) =>
          row.deviceId === deviceId &&
          row.occurredAt.getTime() >= since.getTime(),
      )
      .sort((a, b) => a.occurredAt.getTime() - b.occurredAt.getTime());
  }
}
