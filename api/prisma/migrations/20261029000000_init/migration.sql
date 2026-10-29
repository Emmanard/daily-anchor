-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "EventType" AS ENUM ('routine_completed', 'routine_undone', 'recall_completed', 'feedback_submitted');

-- CreateTable
CREATE TABLE "events" (
    "id" UUID NOT NULL,
    "deviceId" UUID NOT NULL,
    "type" "EventType" NOT NULL,
    "payload" JSONB NOT NULL,
    "occurredAt" TIMESTAMPTZ(3) NOT NULL,
    "receivedAt" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "events_deviceId_occurredAt_idx" ON "events"("deviceId", "occurredAt");

