-- CGMS local schema (drift / SQLite, encrypted with SQLCipher).
-- All IDs are client-generated UUIDv4 so records never collide across devices.
--
-- This SQL is the reference for the drift table definitions in core/db/.
-- See docs/PRODUCTION_ROADMAP.md — Phase P0 (frozen at Gate G1).

CREATE TABLE centres (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, icds_code TEXT,
  sector TEXT, block TEXT
);

CREATE TABLE children (
  id TEXT PRIMARY KEY,
  centre_id TEXT NOT NULL REFERENCES centres(id),
  icds_id TEXT,                    -- ICDS/Poshan beneficiary ID if available
  name TEXT NOT NULL,
  sex TEXT NOT NULL CHECK (sex IN ('M','F')),
  dob DATE NOT NULL,
  dob_precision TEXT NOT NULL,     -- 'exact' | 'month' | 'estimated'
  guardian_name TEXT,
  consent_status TEXT NOT NULL,    -- 'none' | 'given' | 'withdrawn'
  consent_recorded_at DATETIME,
  consent_form_ref TEXT,           -- paper form serial number
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE measurements (
  id TEXT PRIMARY KEY,
  child_id TEXT NOT NULL REFERENCES children(id),
  measured_at DATETIME NOT NULL,
  age_days INTEGER NOT NULL,          -- computed at capture, STORED (never re-derived)
  weight_g INTEGER,
  length_mm INTEGER,
  muac_mm INTEGER,
  position TEXT,                      -- 'recumbent' | 'standing'
  oedema INTEGER NOT NULL DEFAULT 0,  -- clinical override: oedema = SAM
  source TEXT NOT NULL,               -- 'device' | 'manual'
  device_serial TEXT,
  device_sequence INTEGER,
  waz REAL, haz REAL, whz REAL, maz REAL,
  classification TEXT,                -- 'normal' | 'mam' | 'sam' | 'overweight' | 'indeterminate'
  flags TEXT,                         -- JSON: implausible values, mode mismatch, etc.
  engine_version TEXT NOT NULL,       -- which LMS engine computed this row
  app_version TEXT NOT NULL,
  worker_id TEXT NOT NULL,
  notes TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE TABLE referrals (
  id TEXT PRIMARY KEY,
  measurement_id TEXT NOT NULL REFERENCES measurements(id),
  referred_to TEXT,                   -- 'ANM' | 'PHC' | 'NRC'
  referred_at DATETIME NOT NULL,
  outcome TEXT,                       -- 'pending' | 'attended' | 'not_attended' | 'unknown'
  outcome_recorded_at DATETIME
);

CREATE TABLE outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,               -- 'child' | 'measurement' | 'referral'
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL,                   -- 'upsert' | 'delete'
  payload TEXT NOT NULL,              -- JSON snapshot
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  queued_at DATETIME NOT NULL,
  UNIQUE(entity, entity_id, op, queued_at)
);

CREATE INDEX idx_meas_child ON measurements(child_id, measured_at DESC);
CREATE INDEX idx_children_centre ON children(centre_id, deleted);
