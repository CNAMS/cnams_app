# Leftover & Backlog

A single place to see everything not yet done: items **deferred out of the
delivered phases (P0–P4)** and the **full scope of P5 and P6**. Kept honest —
"delivered" phases still have gaps, and they're all listed here.

Legend: 🧩 code work · 🌾 field/clinical work · 🔌 needs backend/hardware ·
📄 data/asset · ✅ has a structural seam in code, needs finishing.

---

## Deferred out of P0–P4 (delivered phases)

| # | Item | From | Type | Notes / blocker |
|---|---|---|---|---|
| 1 | **Load the official WHO LMS tables** into `assets/who_reference/tables.json` | P2 | 📄 | Closes **Gate G2**. Published WHO data, not fabricated. Until then every real z-score and the growth-curve bands are `indeterminate`/empty (fail-safe). Everything downstream is ready for the drop-in. |
| 2 | Golden-corpus validation vs WHO Anthro | P2 | 🧩📄 | The skipped test in `test/zscore/zscore_engine_test.dart`. Needs #1 first, then a per-row diff report (`\|Δz\| ≤ 0.01`). |
| 3 | Real BLE hardware verification | P3 | 🔌 | `RealDeviceClient` compiles against flutter_blue_plus but is untested against a bench unit; the frozen GATT UUIDs must be filled in and it must be swapped into `deviceClientProvider`. Mock stays default. |
| 4 | **AWW usability session** (2 workers, SUS + think-aloud) | P3 | 🌾 | **Gate G3** sign-off. |
| 5 | Bundle a Devanagari font for the parent-card PDF | P3→P6 | 📄 | Today the card fetches Noto Sans Devanagari via the printing package (cached after first use); fully-offline printing needs the font bundled as an asset. |
| 6 | Live `POST /v1/sync/batch` server endpoint | P4 | 🔌 | `SyncService` + `HttpSyncApi` are done and unit-tested against a fake; they need a real server (server track) and a configurable base URL in settings. |
| 7 | `workmanager` scheduling of the sync worker | P4 | 🧩🔌 | The batch logic is done; the periodic (15 min + on-connectivity) trigger and background-isolate entrypoint are not wired. |
| 8 | Full SQLCipher wiring | P4 | ✅🔌 | `openConnection` applies `PRAGMA key`; still needed: Android `open.override` to the SQLCipher build, opening the DB **after** PIN unlock with a PIN-derived key, and migrating any existing plaintext DB. |
| 9 | CSV column-order sign-off with an AWW | P4 | 🌾 | Part of **Gate G4**. `poshanTrackerColumns` is the working definition. |
| 10 | 500-record + kill-mid-batch integrity test | P4 | 🧩🌾 | `NFR-9`. Unit tests cover batch/dead-letter/idempotency logic; the forced-kill durability test is a device/field exercise. |
| 11 | Devanagari vs Latin numerals decision | P0 | 🌾 | To settle in the W3–W6 AWW interviews, then apply in formatters. |
| 12 | Target device `minSdk` / minimum-spec commitment | P0 | 🌾 | Pick from the oldest phone AWWs actually use; profile on it. |
| 13 | Dark theme | P0/P6 | 🧩 | App ships light-only (`AppTheme.light()`); add a dark palette. |
| 14 | CI on real hardware / release signing | P0/P6 | 🔌 | CI builds a debug APK; release signing config and a device matrix are not set up. |

---

## Phase P5 — Field Hardening & Validation (not started)

**Goal:** survive real field conditions and support the formal agreement study.

### Code work 🧩
- [ ] **Referral flow + follow-up** (`FR-APP-9`): raise a referral from a result (ANM/PHC/NRC),
      then record the outcome (`pending`/`attended`/`not_attended`/`unknown`) on a later visit.
      DAO (`ReferralsDao`) and screen stub already exist.
- [ ] **Centre view** (`FR-APP-14`): screened this month, flagged, overdue — the AWW's own rollup.
      Screen stub exists.
- [ ] Paired-record (device vs manual) export for the agreement study.
- [ ] Offline hardening pass: full airplane-mode end-to-end (register → capture → result → referral →
      export) verified and any gaps closed.

### Field / clinical work 🌾
- [ ] App used in the **agreement/validation study**; study data collected clean.
- [ ] **Usability iteration** from field observation; reduce taps per child (`NFR-7`, `NFR-8` measured
      before/after).
- [ ] Field checklist runs: BLE drop mid-reading, battery death mid-session, outdoor daylight legibility.

### Exit criteria / DoD
- [ ] Airplane-mode end-to-end passes.
- [ ] Referral outcomes recordable across visits and reflected in the centre view.
- [ ] Agreement-study data collected clean; paired export validated.
- [ ] Taps-per-child measured before/after; `NFR-7`/`NFR-8` met.

---

## Phase P6 — Polish, Release & Handover (not started)

**Goal:** a stable, signed release an AWW can install and use unaided, documented in Hindi.

### Code work 🧩
- [ ] Crash fixes; crash reporting instrumented.
- [ ] Empty states and **all** error messages in Hindi.
- [ ] Dark theme finalised (see leftover #13).
- [ ] Bundle the Devanagari PDF font (leftover #5).
- [ ] Release build config + app signing; reproducible release APK from CI.

### Field / release work 🌾
- [ ] **Zero crashes across a 2-week field window** (instrumented).
- [ ] Install guide + Hindi user-manual sections.
- [ ] An AWW installs and uses the app **unaided** in an observed session.

### Exit criteria / DoD — **Gate G5 (release readiness)**
- [ ] Zero crashes over the 2-week window.
- [ ] Signed release APK, reproducible from CI.
- [ ] Install guide + Hindi manual complete.
- [ ] AWW installs and uses unaided → handover.

---

## The Ankur experience layer (new, planned separately)

The branding, landing page, role-based auth (AWW / Supervisor / Doctor / Parent / Admin), Google
OAuth, role dashboards, and theme refresh are planned in
[ANKUR_EXPERIENCE_ROADMAP.md](ANKUR_EXPERIENCE_ROADMAP.md) as their own phase track (EX0–EX5). They
layer on top of the P0–P6 functional core and are **not started** in code yet.

---

## Quick status snapshot

| Phase | Status |
|---|---|
| P0 Foundation | ✅ delivered (device-spec + dark theme deferred) |
| P1 Roster & data core | ✅ delivered |
| P2 Engine & mock capture | ✅ code delivered · 📄 WHO tables + Gate G2 pending |
| P3 Device & result UX | ✅ code delivered · 🔌 hardware + 🌾 Gate G3 pending |
| P4 Sync, security & export | ✅ code delivered · 🔌 server/workmanager/SQLCipher + 🌾 Gate G4 pending |
| P5 Field hardening | ⬜ not started (mostly field) |
| P6 Polish & release | ⬜ not started (mostly field) |
| EX0–EX5 Ankur experience | ⬜ planned, not started |
