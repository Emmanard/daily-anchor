import express, { type ErrorRequestHandler } from 'express';

import { buildProgress, progressStart } from './progress';
import {
  batchEnvelopeSchema,
  MAX_BATCH_SIZE,
  parseEvent,
  progressQuerySchema,
} from './schemas';
import type { EventStore, NewEvent } from './store';

interface Rejected {
  index: number;
  /** The id the client sent, or null when it sent none. */
  id: string | null;
  reason: string;
}

function apiError(code: string, message: string) {
  return { error: { code, message } };
}

function idOf(raw: unknown): string | null {
  if (typeof raw === 'object' && raw !== null && 'id' in raw) {
    const id = (raw as { id: unknown }).id;
    if (typeof id === 'string') return id.slice(0, 64);
  }
  return null;
}

const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  const type = (err as { type?: string }).type;
  if (type === 'entity.parse.failed') {
    res.status(400).json(apiError('invalid_json', 'Request body is not valid JSON.'));
    return;
  }
  if (type === 'entity.too.large') {
    res.status(413).json(apiError('payload_too_large', 'Request body is too large.'));
    return;
  }
  // Only the error name is logged: database errors can quote the stored values.
  console.error('Unhandled error:', (err as Error)?.name ?? 'unknown');
  res.status(500).json(apiError('internal_error', 'Something went wrong.'));
};

export interface AppDependencies {
  store: EventStore;
  now?: () => Date;
}

export function createApp({ store, now = () => new Date() }: AppDependencies) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '512kb' }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.post('/events', async (req, res) => {
    const envelope = batchEnvelopeSchema.safeParse(req.body);
    if (!envelope.success) {
      res
        .status(400)
        .json(
          apiError(
            'invalid_request',
            'Body must be { deviceId: uuid, events: array }.',
          ),
        );
      return;
    }

    const { deviceId, events } = envelope.data;
    if (events.length > MAX_BATCH_SIZE) {
      res
        .status(413)
        .json(
          apiError(
            'batch_too_large',
            `At most ${MAX_BATCH_SIZE} events per request.`,
          ),
        );
      return;
    }

    const rejected: Rejected[] = [];
    const duplicates: string[] = [];
    const valid: NewEvent[] = [];
    const seen = new Set<string>();

    events.forEach((raw, index) => {
      const parsed = parseEvent(raw, now());
      if (!parsed.ok) {
        rejected.push({ index, id: idOf(raw), reason: parsed.reason });
        return;
      }
      // The same id twice in one batch: the first is kept.
      if (seen.has(parsed.event.id)) {
        duplicates.push(parsed.event.id);
        return;
      }
      seen.add(parsed.event.id);
      valid.push({ ...parsed.event, deviceId });
    });

    const inserted = new Set(await store.insertNew(valid));
    const accepted: string[] = [];
    for (const event of valid) {
      (inserted.has(event.id) ? accepted : duplicates).push(event.id);
    }

    res.json({ accepted, duplicates, rejected });
  });

  app.get('/progress', async (req, res) => {
    const query = progressQuerySchema.safeParse(req.query);
    if (!query.success) {
      res
        .status(400)
        .json(
          apiError(
            'invalid_request',
            'Query must have deviceId (uuid), and optional days (1-90) and utcOffsetMinutes.',
          ),
        );
      return;
    }

    const { deviceId, days, utcOffsetMinutes } = query.data;
    const current = now();
    const events = await store.forDevice(
      deviceId,
      progressStart(current, days, utcOffsetMinutes),
    );
    res.json({
      deviceId,
      days: buildProgress(events, current, days, utcOffsetMinutes),
    });
  });

  app.use((_req, res) => {
    res.status(404).json(apiError('not_found', 'Route not found.'));
  });
  app.use(errorHandler);

  return app;
}
