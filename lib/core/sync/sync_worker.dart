// workmanager task: batch <=50, POST /v1/sync/batch, per-record status,
// exponential backoff 30s->1h. Never blocks UI (FR-APP-13, CON-7). Phase P4.
