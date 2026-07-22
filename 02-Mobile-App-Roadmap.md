# Track B — Mobile Application Roadmap

**Owns:** `FR-APP-1..18`, hosts `FR-ALG` on-device
**Team:** 2 mobile developers
**Repo:** `growth-monitor-app`
**Stack:** Flutter 3.x · Riverpod · drift (SQLite) · flutter_blue_plus · fl_chart · workmanager · printing

---

## 1. Architecture

```
lib/
├── main.dart
├── core/
│   ├── db/              drift schema, DAOs, migrations
│   ├── ble/             device client, mock client, packet codec
│   ├── sync/            outbox, sync worker, conflict policy
│   ├── zscore/          WHO LMS engine + bundled reference tables
│   ├── auth/            PIN, token store (flutter_secure_storage)
│   └── l10n/            hi.arb (primary), en.arb
├── features/
│   ├── roster/          child list, registration, consent
│   ├── measure/         device pairing, capture flow, classification result
│   ├── history/         per-child growth curve, previous visits
│   ├── centre/          AWW's own dashboard: screened, flagged, overdue
│   ├── referral/        SAM/MAM referral capture and follow-up
│   └── export/          CSV in Poshan Tracker order, parent growth card PDF
└── shared/              widgets, theme, formatters
```

**Layering rule:** `features/` may depend on `core/`, never the reverse, and nothing in `core/zscore/` may import Flutter. The engine must be pure Dart so it can be tested headlessly and diffed against the Python implementation.

---

## 2. Local data model (drift / SQLite)

```sql
-- All IDs are client-generated UUIDv4 so records never collide across devices.

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
  age_days INTEGER NOT NULL,          -- computed at capture, stored
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
  engine_version TEXT NOT NULL,
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
```

**Non-obvious decisions, and why:**

- `age_days` is **stored, not derived**. Recomputing age later against a corrected DOB would silently change a historical z-score. Store what was used.
- `engine_version` on every row. When you fix a bug in the LMS code, you need to know which records were computed with the broken version.
- `dob_precision` exists because rural DOBs are frequently approximate. An estimated DOB propagates a large error into WAZ and HAZ, and this must be visible in your analysis, not hidden.
- `oedema` is a manual flag that forces SAM regardless of z-score, per WHO. It is the one clinical input you must accept.
- `deleted` is a soft flag — hard deletion happens only via the consent-withdrawal path, and is mirrored server-side (`FR-SRV-8`).

---

## 3. Screen inventory

| # | Screen | Purpose | Key requirement |
|---|---|---|---|
| 1 | PIN unlock | Auth | FR-APP-16 |
| 2 | Home | Device status, battery, calibration age, sync backlog, today's list | FR-APP-17 |
| 3 | Child roster | Search, filter by overdue, add child | FR-APP-5 |
| 4 | Child registration | Name, sex, DOB + precision, guardian, consent capture | FR-APP-15 |
| 5 | Device pairing | Scan, connect, reconnect, manual-entry fallback | FR-APP-3, 4 |
| 6 | Capture — weight | Live value, stability indicator, confirm | FR-APP-2 |
| 7 | Capture — length | Mode check vs age, live value, confirm | FR-APP-8 |
| 8 | Capture — MUAC | Manual numeric entry, oedema checkbox | FR-ALG-4 |
| 9 | **Result** | Colour band + Hindi label, then z-scores, then referral prompt | FR-APP-7, 9 |
| 10 | Child history | Growth curve vs WHO bands, previous visits | FR-APP-10 |
| 11 | Parent card | Preview, share via WhatsApp, print | FR-APP-11 |
| 12 | Centre view | Screened this month, flagged, overdue | FR-APP-14 |
| 13 | Referral follow-up | Record outcome on a later visit | FR-APP-9 |
| 14 | Export | CSV in Poshan Tracker column order | FR-APP-12 |
| 15 | Settings | Language, sync now, device management, about | — |

### The Result screen is the product

Everything else is plumbing. Design rules for screen 9:

1. **Colour and Hindi word first**, occupying the top half. Green / yellow / red with a text label — never colour alone, some workers may have colour vision deficiency and the card may be photocopied in greyscale.
2. Numeric z-scores below the fold, not above it.
3. The referral prompt is a **decision the worker makes**, not an instruction the app issues. Wording matters here — `CON-5`. Phrase as "इस बच्चे को ANM को दिखाने की सलाह दी जाती है" (referral is advised), not "refer this child".
4. One tap to save and move to the next child. The AWW has 15 more children waiting.

---

## 4. Sync design

```
capture ──► local write (SQLite) ──► enqueue outbox ──► UI returns immediately
                                            │
                       workmanager, every 15 min + on connectivity change
                                            ▼
                       batch ≤ 50 records ──► POST /v1/sync/batch
                                            │
                       per-record status ◄──┘
                       200 → delete from outbox
                       409 → conflict, apply server policy, log
                       4xx → move to dead-letter, surface in Settings
                       5xx / timeout → exponential backoff (30 s → 1 h cap)
```

Rules:
- **Idempotency key** = the record's UUID. The server must treat a repeat as a no-op (`FR-SRV-2`).
- Sync **never** blocks the UI, and no screen ever shows a network spinner during measurement (`FR-APP-13`, `CON-7`).
- Failed records stay in the outbox indefinitely — never dropped silently. Settings shows the backlog count and last error.
- Conflict policy: last-write-wins by `updated_at`, superseded version retained server-side (`FR-SRV-4`).
- Test with 500 queued records and forced kills mid-batch (`NFR-9`).

---

## 5. Sprint plan

### Semester 1

| Weeks | Sprint | Deliverable | Exit criterion |
|---|---|---|---|
| 1–2 | B0 Setup | Flutter project, CI, theme, Hindi l10n scaffolding | Builds on the target phone |
| 3–4 | B1 Learn + schema | Team upskilling; drift schema, DAOs, migrations | Schema reviewed, tests pass |
| 5–6 | B2 Roster | Registration, consent capture, child list | Add/edit/search works offline |
| 7–8 | **B3 Z-score engine** | Pure-Dart LMS engine + WHO tables bundled | **Gate G2** — matches WHO Anthro |
| 9–10 | B4 Mock BLE | `DeviceClient` interface + fake implementation, capture flow | Full capture flow on synthetic data, no hardware needed |
| 11–12 | B5 Real BLE | flutter_blue_plus against the frozen GATT spec | Live values from the bench unit |
| 13–14 | B6 Result + history | Result screen, growth curve, parent card draft | Usability session with 2 AWWs |
| 15–16 | B7 Review | Sem 1 build, findings from usability, redesign backlog | Sem 1 report |

### Semester 2

| Weeks | Sprint | Deliverable | Exit criterion |
|---|---|---|---|
| 1–2 | B8 Sync | Outbox, workmanager, backoff, dead-letter | 500-record integrity test passes |
| 3–4 | B9 Security + export | SQLCipher, PIN, token storage, CSV export | **Gate G4**; column order approved by an AWW |
| 5–6 | B10 Field build | Referral flow, centre view, offline hardening | Airplane-mode end-to-end passes |
| 7–8 | B11 Validation support | Capture app used in the agreement study; paired-record export | Study data collected clean |
| 9–10 | B12 Usability iteration | Redesign from field observation; taps per child reduced | NFR-7, NFR-8 measured |
| 11–12 | B13 Polish | Crash fixes, empty states, error messages in Hindi | Zero crashes across a 2-week field window |
| 13–14 | B14 Handover | Signed APK, install guide, Hindi manual sections | AWW installs and uses unaided |

---

## 6. Test strategy

| Level | What | Tool |
|---|---|---|
| Unit | Z-score engine against the golden corpus | `flutter test`, golden JSON |
| Unit | Packet codec, CRC, age calculation, boundary at 24 months | `flutter test` |
| Widget | Result screen renders each classification correctly | `flutter_test` |
| Integration | Capture → store → outbox → sync, with mock server | `integration_test` |
| Manual | Airplane mode end-to-end; BLE drop mid-reading; battery death mid-session | Field checklist |
| Usability | SUS + think-aloud, 4–6 AWWs, two rounds | Recorded with consent |

**Mandatory practice:** the mock BLE client is not a testing convenience, it is the schedule protection for this track. Build it in sprint B4 and keep it working all the way to handover — it means the mobile team is never blocked by a broken load cell or a printer queue.

---

## 7. Localisation and accessibility

- All strings in `hi.arb` from sprint B0. A lint rule fails the build on hardcoded user-facing text (`NFR-16`).
- Hindi first, English fallback — not the other way round. The default locale is `hi`.
- Numerals: Devanagari vs Latin digits must be decided **with the AWWs**, not by the team. Ask in the W3–W6 interviews.
- Minimum touch target 48 dp; base font 16 sp with system scaling honoured.
- Every status conveyed by colour must also carry text or an icon.
- Test on the actual target phone in outdoor daylight — screens that look fine in the lab wash out in a courtyard.
