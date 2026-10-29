import { z } from 'zod';

export const MAX_BATCH_SIZE = 100;

/** Events may be this far ahead of the server clock, to allow for clock drift. */
const MAX_FUTURE_MS = 24 * 60 * 60 * 1000;

export const eventTypes = [
  'routine_completed',
  'routine_undone',
  'recall_completed',
  'feedback_submitted',
] as const;

export type EventType = (typeof eventTypes)[number];

// Unknown keys are dropped, so only the fields below are ever stored.
const routinePayload = z.object({ routineId: z.string().min(1).max(64) });

const recallPayload = z.object({
  correctCount: z.int().min(0).max(5),
  durationMs: z.int().min(0).max(3_600_000),
});

const feedbackPayload = z.object({
  message: z.string().trim().min(1).max(500),
});

const common = {
  id: z.uuid(),
  occurredAt: z.iso.datetime(),
};

export const eventSchema = z.discriminatedUnion('type', [
  z.object({
    ...common,
    type: z.literal('routine_completed'),
    payload: routinePayload,
  }),
  z.object({
    ...common,
    type: z.literal('routine_undone'),
    payload: routinePayload,
  }),
  z.object({
    ...common,
    type: z.literal('recall_completed'),
    payload: recallPayload,
  }),
  z.object({
    ...common,
    type: z.literal('feedback_submitted'),
    payload: feedbackPayload,
  }),
]);

export interface ParsedEvent {
  id: string;
  type: EventType;
  payload: Record<string, unknown>;
  occurredAt: Date;
}

export type ParseResult =
  | { ok: true; event: ParsedEvent }
  | { ok: false; reason: string };

/**
 * Validates one event from a batch. The reason never repeats what the client
 * sent, because an event can carry free text.
 */
export function parseEvent(raw: unknown, now: Date): ParseResult {
  const result = eventSchema.safeParse(raw);
  if (!result.success) {
    const issue = result.error.issues[0];
    const path = issue?.path.join('.') || 'event';
    return { ok: false, reason: `${path}: ${issue?.code ?? 'invalid'}` };
  }

  const occurredAt = new Date(result.data.occurredAt);
  if (occurredAt.getTime() > now.getTime() + MAX_FUTURE_MS) {
    return { ok: false, reason: 'occurredAt: too_far_in_future' };
  }
  return {
    ok: true,
    event: {
      id: result.data.id,
      type: result.data.type,
      payload: result.data.payload,
      occurredAt,
    },
  };
}

export const batchEnvelopeSchema = z.object({
  deviceId: z.uuid(),
  events: z.array(z.unknown()),
});

export const progressQuerySchema = z.object({
  deviceId: z.uuid(),
  days: z.coerce.number().int().min(1).max(90).default(7),
  // Minutes ahead of UTC for the device's local day boundaries.
  utcOffsetMinutes: z.coerce.number().int().min(-720).max(840).default(0),
});
