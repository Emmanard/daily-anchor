# Daily Anchor: API

A small Node.js API for the Daily Anchor app. It receives the app's events, stores each one once, and returns a per-day progress summary. The project overview and decision log are in the [main README](../README.md).

Stack: Node 22, Express 5, TypeScript, Zod, Prisma 7 with PostgreSQL, Vitest and Supertest.

## Endpoints

| Request | Result |
|---|---|
| `GET /health` | `{ "status": "ok" }` |
| `POST /events` with `{ "deviceId": uuid, "events": [...] }` | `{ "accepted": [ids], "duplicates": [ids], "rejected": [{ "index", "id", "reason" }] }`. At most 100 events per request. A bad event is rejected on its own, and an id that is already stored is reported as a duplicate and never stored twice |
| `GET /progress?deviceId=...&days=7&utcOffsetMinutes=0` | One entry per day with `routinesCompleted` and `recallAttempts`, oldest first |

## Environment variables

Names only. No values are stored in the repository, and the API reads them from the process environment, never from a file.

| Variable | Used by | Purpose |
|---|---|---|
| `POSTGRES_PASSWORD` | `docker compose` | Password for the local PostgreSQL container (you choose it; no default) |
| `DATABASE_URL` | API, `prisma migrate` | Connection string for the development database |
| `TEST_DATABASE_URL` | tests | Connection string for a separate, disposable test database |
| `PORT` | API | Optional, defaults to 3000 |

## Run it

Needs Node 22.18 or newer and Docker.

```bash
npm install
export POSTGRES_PASSWORD='letters-and-numbers-only'
docker compose up -d                                       # local PostgreSQL 17
docker compose exec -T db createdb -U daily_anchor daily_anchor_test
export DATABASE_URL="postgresql://daily_anchor:${POSTGRES_PASSWORD}@localhost:5432/daily_anchor"
export TEST_DATABASE_URL="postgresql://daily_anchor:${POSTGRES_PASSWORD}@localhost:5432/daily_anchor_test"
npm run migrate:deploy                                     # create the tables
DATABASE_URL="$TEST_DATABASE_URL" npm run migrate:deploy   # and in the test database
npm run dev                                                # start on PORT (default 3000)
```

PostgreSQL keeps the password it was first created with. If you later use a different one, reset the local data with `docker compose down -v`.

## Tests

```bash
npm run typecheck
npm test
```

Most tests need no database. The tests in `test/prisma-store.test.ts` need PostgreSQL with the migrations applied, run only when `TEST_DATABASE_URL` is set, and delete all events, so they never use `DATABASE_URL`.
