# Project Updates & Cross-Team Handoff

**Component:** Ankur — mobile app (Track B) of the Child Growth Management System (CGMS)
**Status date:** 2026-07-25
**Repos:** `PranavShukla2/cgms` (`main`) · `CNAMS/cnams_app` (`Pranav`)

This is the running status of the **mobile app** and — more importantly — a precise
list of what the app needs from the **other tracks** (Data, IoT/Hardware, Backend,
Clinical/Field). Each ask names the exact code seam it plugs into, so integration
is drop-in, not rework.

Companion docs: [PRODUCTION_ROADMAP.md](PRODUCTION_ROADMAP.md) ·
[ANKUR_EXPERIENCE_ROADMAP.md](ANKUR_EXPERIENCE_ROADMAP.md) ·
[LEFTOVER.md](LEFTOVER.md) · [BUG_AUDIT.md](BUG_AUDIT.md).

---

## 1. What the mobile app has done ✅

**Foundation & data (P0–P1)**
- Flutter app, Hindi-first (default) with a runtime **Hindi ⇄ English** switch; a
  build-failing lint on hardcoded strings; CI (format, analyze, test, build).
- Offline SQLite (drift) schema — centres, children, measurements, referrals,
  outbox — with client-generated UUIDs, stored `age_days`, per-row engine/app
  version, soft delete.
- Repositories over the DB; **child registration + consent**, roster with search
  and overdue filter — all fully offline.

**Growth engine & capture (P2–P3)**
- Pure-Dart **WHO LMS z-score engine**: z-score math with the >3/<−3 tail
  extrapolation, reference-table interpolation, the 24-month length/height
  boundary + 0.7 cm position correction, and WHO classification (SAM / MAM /
  overweight / indeterminate, oedema override, MUAC cut-offs).
- **Mock BLE device** + packet codec (CRC) → the full **capture flow**
  (weight → length → MUAC/oedema → result) runs with no hardware.
- **Child history** hub with a weight-for-age growth curve, and a **parent card**
  (PDF preview / share / print). Real-BLE client skeleton behind the interface.

**Sync, security & export (P4)**
- Durable **outbox sync engine**: batch ≤50, 200/409 remove, 4xx dead-letter,
  5xx/transport backoff, UUID idempotency — unit-tested incl. a 120-record drain.
- **PIN unlock** (PBKDF2) with **brute-force lockout**; **email+password** and
  **OTP** sign-in (PBKDF2-hashed); secure-storage sessions.
- **CSV export** in Poshan Tracker column order.

**Ankur experience layer (EX0–EX5)**
- Brand + per-role themes (AWW / Supervisor / Doctor / Parent / Admin), dark mode,
  animated splash, **language-first onboarding**, role-based **sign-in**
  (Google / phone OTP / email OTP / email+password / PIN), **five role
  dashboards** (incl. admin app-analytics), a **role-aware navigation shell**, and
  a bug/security fix pass.

**Quality:** 116 tests pass; analyze, formatting and the hardcoded-string check
are clean on every push.

> **Important caveat:** the app runs today on **mocks and placeholders** for
> everything owned by other tracks (WHO data, hardware, servers). It is built so
> each real deliverable slots into a defined seam — see §2.

---

## 2. What we need from other groups 🔗

### 2.1 Data / Analytics team

| # | Deliverable | Plugs into | Blocks |
|---|---|---|---|
| D1 | **Official WHO LMS reference tables** (weight-for-age, length/height-for-age, weight-for-length, weight-for-height, MUAC-for-age; both sexes) as JSON | `assets/who_reference/tables.json` — **format & units documented in** [`assets/who_reference/README.md`](../assets/who_reference/README.md) | **Everything clinical.** Until this lands, every z-score is `indeterminate` (fail-safe) and the growth-curve bands are empty. Closes **Gate G2**. |
| D2 | **Golden validation corpus** — a set of (sex, age, weight, length, MUAC) inputs with the WHO-Anthro-computed z-scores + classification | `test/zscore/golden_corpus.json` (skipped test `zscore_engine_test.dart` is ready to consume it) | Formal engine sign-off at Gate G2 (target \|Δz\| ≤ 0.01). |
| D3 | **Poshan Tracker column order** — the exact import column layout, confirmed | `poshanTrackerColumns` in `lib/features/export/csv_export.dart` | CSV import acceptance; part of **Gate G4**. |

Format for D1/D2 is fixed and small — one JSON entry per indicator+sex, one row
per tabulated point. We can write the converter if given the source files.

### 2.2 IoT / Hardware team

| # | Deliverable | Plugs into | Blocks |
|---|---|---|---|
| H1 | **Frozen GATT spec** — BLE service UUID, measurement characteristic UUID(s), advertised device-name prefix | constructor args of `RealDeviceClient` (`serviceUuid`, `measurementCharUuid`, `deviceNamePrefix`) in `lib/core/ble/real_device_client.dart` | Real-device connection. |
| H2 | **On-wire packet format** — byte layout of a weight/length notification (fields, endianness, CRC) | `PacketCodec` in `lib/core/ble/packet_codec.dart` — currently a self-consistent placeholder frame; align it to the real spec | Correct decoding of live readings. |
| H3 | A **bench unit** (load cell + stadiometer) to test against | verifies `RealDeviceClient` end-to-end and lets us swap it into `deviceClientProvider` | Hardware verification (P3); the mock keeps us unblocked until then. |
| H4 | **Calibration & stability semantics** — what "stable" means, calibration-age reporting, MUAC input path (device vs manual) | capture flow stability indicator; Home device-status card (P4) | Trustworthy field readings. |

Everything downstream of the device already works on the mock, so H1–H2 are a
UUID + byte-layout drop-in.

### 2.3 Backend / Server team

| # | Deliverable | Plugs into | Blocks |
|---|---|---|---|
| S1 | **Sync endpoint** `POST /v1/sync/batch` — accept a batch of records (UUID = idempotency key), return **per-record status** (200 ok / 409 conflict / 4xx reject / 5xx). Conflict policy: last-write-wins by `updated_at`, superseded retained server-side | `HttpSyncApi` in `lib/core/sync/sync_api.dart` (contract + request/response shape already defined); swap in for the mock | Real multi-device sync. |
| S2 | **Identity service** — `/v1/auth/oauth/google`, `/v1/auth/otp/request`, `/v1/auth/otp/verify`, `/v1/auth/password`, `/v1/auth/profile`, `/v1/auth/refresh`; **OTP delivery (SMS/email)**; **role approval** (no self-granted admin) | `AuthApi` in `lib/core/auth/auth_api.dart` (mock implements the same interface) | Real accounts, roles, and cross-role data scoping. |
| S3 | **Role-scoped data APIs** — supervisor sector rollups, doctor referral inbox, parent's linked child, admin user/centre management | the role dashboards (currently sample data behind a "sample" chip) | Live dashboards (EX3). |
| S4 | **App telemetry** — crash reporting + metrics (crash-free rate, API latency, active users by role, version spread) | admin **App analytics** screen (sync counts are already real; perf metrics are illustrative) | Real ops view; P6 crash reporting. |
| S5 | **SQLCipher key policy** — confirm the at-rest encryption approach for the server mirror | mirrors the app's `openConnection(passphrase)` seam | Consistent encryption story. |

### 2.4 Clinical / Field team

| # | Deliverable | Blocks |
|---|---|---|
| C1 | **AWW usability sessions** (2 workers, SUS + think-aloud) | **Gate G3** sign-off (P3). |
| C2 | **Agreement / validation study** (device vs manual, paired records) | P5 validation; paired export is ready. |
| C3 | **Referral pathways** — confirm ANM/PHC/NRC routing + outcome vocabulary | referral flow (P5). |
| C4 | **Consent form** serials/process, and the **Devanagari vs Latin numerals** decision | consent capture (done) + number formatting. |
| C5 | **Parent↔child linking** policy (e.g. AWW-issued invite code) | parent dashboard is a sample until this is decided. |

### 2.5 Design / Content

- **Bundle a Devanagari font** for fully-offline PDF printing (parent card currently
  fetches Noto Sans Devanagari once, then caches).
- Review the **Hindi copy** and produce the **Hindi user-manual** sections (P6).

### 2.6 Admin / Project team (us)

- Approve role requests, set up centres/sectors, and own the **app-analytics**
  operations view once telemetry (S4) exists.

---

## 3. Integration contracts already in place

These interfaces are built and tested against mocks — implementing the real side
means satisfying the contract, nothing in the UI/logic changes:

- **`AuthApi`** → identity service (S2)
- **`SyncApi` / `HttpSyncApi`** → sync endpoint (S1)
- **`DeviceClient`** (mock + real) → hardware (H1–H3)
- **`ReferenceTables` + `tables.json`** → WHO data (D1)
- **`SecureStore`** → platform keystore (done)

## 4. Open decisions needing cross-team input

1. Auth: which methods per role (parents may lack Google — phone OTP likely primary).
2. Backend ownership & timeline for the identity + telemetry services.
3. Program-analytics depth for v1 (counts + trends vs per-child drill-down).
4. Offline support for non-AWW roles (read-only cache vs online-only).
5. Target Android minimum spec (pick from the oldest phone AWWs actually use).

## 5. Suggested integration order

1. **D1 WHO tables** (unblocks all clinical output) →
2. **H1/H2 GATT spec** (real readings) →
3. **S1 sync endpoint** (durable multi-device) →
4. **S2 identity** (real roles/scoping) →
5. **S3 role APIs + S4 telemetry** (live dashboards) →
6. **C1 usability + C2 study** (field validation, Gates G3/G4).
