import type { EventType } from './schemas';

export interface NewEvent {
  id: string;
  deviceId: string;
  type: EventType;
  payload: Record<string, unknown>;
  occurredAt: Date;
}

export interface StoredEvent extends NewEvent {
  receivedAt: Date;
}

export interface EventStore {
  /**
   * Stores the events whose ids are not stored yet and returns the ids it
   * inserted. An id that already exists is skipped, never overwritten.
   */
  insertNew(events: NewEvent[]): Promise<string[]>;

  /** The device's events that occurred at or after [since], oldest first. */
  forDevice(deviceId: string, since: Date): Promise<StoredEvent[]>;
}
