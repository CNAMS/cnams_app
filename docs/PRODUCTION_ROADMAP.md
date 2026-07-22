# CGMS Mobile App — Production Roadmap

**Project:** Child Growth Management System (CGMS) — Track B, Mobile Application
**Component:** Field data-capture app for Anganwadi Workers (AWWs)
**Repo:** `cgms` (this folder is the app component)
**Stack:** Flutter 3.x · Riverpod · drift (SQLite/SQLCipher) · flutter_blue_plus · fl_chart · workmanager · printing
**Owns:** `FR-APP-1..18`, hosts `FR-ALG` (WHO LMS z-score engine) on-device

> This document is the detailed, production-grade expansion of [`02-Mobile-App-Roadmap.md`](../02-Mobile-App-Roadmap.md).
> The rough roadmap defines *what* each sprint delivers. This document defines *how* each phase is
> built, gated, tested, and shipped, with concrete entry/exit criteria, risks, and definitions of done.

---

## 0. How to read this document

The work is organised into **7 production phases** (P0–P6) that map onto the two-semester sprint plan.
Each phase has:

- **Goal** — the single outcome that defines the phase.
- **Scope** — the features and requirements delivered (`FR-*` / `NFR-*` references from the master spec).
- **Entry criteria** — what must be true before the phase starts.
- **Exit criteria / Definition of Done (DoD)** — objective, testable conditions for phase completion.
- **Gates** — formal review checkpoints (`G0`–`G5`) that block progression until signed off.
- **Key risks & mitigations**.

Phases are sequential in intent but overlap in practice; the **mock BLE client (P2)** exists precisely
so downstream phases are never blocked by hardware.

### Phase → Sprint map

| Phase | Theme | Sprints (rough roadmap) | Semester |
|---|---|---|---|
| **P0** | Foundation & tooling | B0, B1 | Sem 1, W1–4 |
| **P1** | Roster & offline data core | B2 | Sem 1, W5–6 |
| **P2** | Z-score engine + mock capture | B3, B4 | Sem 1, W7–10 |
| **P3** | Real device integration & result UX | B5, B6, B7 | Sem 1, W11–16 |
| **P4** | Sync, security & export | B8, B9 | Sem 2, W1–4 |
| **P5** | Field hardening & validation | B10, B11, B12 | Sem 2, W5–10 |
| **P6** | Polish, release & handover | B13, B14 | Sem 2, W11–14 |

### Quality gates

| Gate | Name | Blocks | Owner sign-off |
|---|---|---|---|
| **G0** | Foundation ready | P1 start | Tech lead |
| **G1** | Data model frozen | P2 engine work | Tech lead + backend lead |
| **G2** | Engine correctness | P3 start | Clinical/algorithm reviewer |
| **G3** | Field-usable build | P4 start | 2 AWWs (usability) |
| **G4** | Security & export | P5 start | Security reviewer + AWW |
| **G5** | Release readiness | Handover | Product owner |

---

## Phase P0 — Foundation & Tooling

**Goal:** A reproducible, CI-verified Flutter project that builds and runs on the *actual target phone*,
with the offline data schema in place and localisation scaffolding enforced from day one.

### Scope
- Flutter project bootstrap, package/versioning strategy, `flutter_gen` for assets/l10n.
- CI pipeline: format check, analyze, test, build APK artifact.
- Theme system (light-first, high-contrast, outdoor-legible), typography scale (base 16 sp).
- Localisation scaffolding: `hi.arb` (primary, default locale), `en.arb` (fallback). Lint rule fails
  the build on hardcoded user-facing strings (`NFR-16`).
- drift schema, DAOs, and migration framework for all entities (`centres`, `children`,
  `measurements`, `referrals`, `outbox`).
- Layering enforcement: `features/` → `core/` only; `core/zscore/` must not import Flutter.

### Data model (frozen at G1)
Implements the schema in the rough roadmap §2. Non-negotiable decisions carried forward:
- `age_days` is **stored, not derived** — never recompute a historical z-score.
- `engine_version` + `app_version` on every measurement row for reproducibility/audit.
- `dob_precision` (`exact` | `month` | `estimated`) surfaced in analysis, never hidden.
- `oedema` manual flag forces SAM regardless of z-score (WHO rule).
- `deleted` is a soft flag; hard deletion only via consent-withdrawal path (mirrors `FR-SRV-8`).
- All primary keys are client-generated **UUIDv4** (offline-safe, collision-free across devices).

### Entry criteria
- Master requirements spec (`FR-*`, `NFR-*`, `CON-*`) available and versioned.
- Target device model confirmed and physically available to the team.

### Exit criteria / DoD
- [ ] `flutter build apk --release` succeeds in CI and installs on the target phone.
- [ ] CI runs `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` on every push.
- [ ] All five tables created via drift migrations; migration test round-trips v1→vN.
- [ ] Hardcoded-string lint active and failing the build on a seeded violation.
- [ ] Architecture layering test passes (no `core/zscore` → Flutter import; no `core` → `features`).
- [ ] **Gate G0** signed off.

### Risks
| Risk | Mitigation |
|---|---|
| Target phone underpowered / old Android | Set `minSdk` from the real device; profile early on it, not an emulator. |
| l10n retrofitted late | Enforce `hi.arb`-only strings from the first widget via lint. |

---

## Phase P1 — Roster & Offline Data Core

**Goal:** An AWW can register, search, edit, and manage children entirely offline, with consent
captured as a first-class, auditable record.

### Scope (`FR-APP-5`, `FR-APP-15`)
- Child roster: search, filter by "overdue for measurement", sort.
- Child registration: name, sex, DOB + `dob_precision`, guardian, ICDS/Poshan ID (optional).
- Consent capture: `none` | `given` | `withdrawn`, timestamp, paper form serial reference.
- Consent-withdrawal path stub (wires to soft-delete + future server mirror).
- Riverpod state architecture: repositories over DAOs, immutable view models.
- Empty states and error messages in Hindi.

### Entry criteria
- G0 signed off; schema available.

### Exit criteria / DoD
- [ ] Add / edit / search / filter children works with the network fully off (airplane mode).
- [ ] Consent status and timestamp persisted and shown on the child record.
- [ ] DOB precision selectable and stored; estimated DOBs visually flagged.
- [ ] Repository + DAO unit tests cover create/update/soft-delete/search.
- [ ] Roster loads < 500 ms with 500 seeded children on the target device.

### Risks
| Risk | Mitigation |
|---|---|
| Rural DOBs approximate | `dob_precision` mandatory; UI nudges toward month/estimated honesty. |
| Duplicate registrations | Search-before-add flow; soft-match on name + guardian + DOB. |

---

## Phase P2 — Z-Score Engine + Mock Capture

**Goal:** A pure-Dart WHO LMS engine that matches the reference implementation to tolerance, plus a
complete capture flow driven by a **mock BLE client** so no downstream work depends on hardware.

### Scope
- **Z-score engine** (`FR-ALG`, `core/zscore/`): WHO LMS method, bundled reference tables (WAZ, HAZ,
  WHZ/WLZ, MUAC-for-age), classification into `normal` | `mam` | `sam` | `overweight` |
  `indeterminate`. Boundary handling at 24 months (recumbent length ↔ standing height, position
  correction). Oedema override. Pure Dart — no Flutter import.
- **Golden corpus** validation: engine output diffed against the Python reference / WHO Anthro across
  a large parameterised corpus (edge ages, extreme z, boundary crossings, missing inputs).
- **Mock BLE client**: `DeviceClient` interface + fake implementation emitting synthetic weight/length
  streams with stability, dropout, and noise simulation.
- **Capture flow** on synthetic data: weight → length (mode-vs-age check) → MUAC (manual + oedema) →
  classification result. No hardware needed.

### Entry criteria
- G1 (data model frozen) signed off.

### Exit criteria / DoD — **Gate G2 (engine correctness)**
- [ ] Engine matches WHO Anthro / Python reference within agreed tolerance across the golden corpus
      (target: |Δz| ≤ 0.01 for all corpus rows; document any allowed exceptions).
- [ ] Classification matches reference on 100% of corpus rows, including oedema override and
      indeterminate cases.
- [ ] Packet codec + CRC + age-calculation unit tests pass, including the 24-month boundary.
- [ ] Full capture flow runs end-to-end on the mock client with zero hardware.
- [ ] `core/zscore` has **no Flutter dependency** (enforced by test).
- [ ] **Gate G2** signed off by the clinical/algorithm reviewer.

### Risks
| Risk | Mitigation |
|---|---|
| Subtle LMS/rounding divergence | Golden corpus + per-row diff report; freeze `engine_version`. |
| Team blocked by hardware later | Mock client is mandatory and kept working to handover. |
| Length/height mode confusion | Age-based mode check with position correction at 24 mo. |

---

## Phase P3 — Real Device Integration & Result UX

**Goal:** Live measurements from the real bench unit, and the **Result screen — the product** — refined
against real AWW usage.

### Scope (`FR-APP-2,3,4,7,8,9,10,11`)
- Real BLE via `flutter_blue_plus` against the **frozen GATT spec**: scan, connect, reconnect,
  manual-entry fallback (`FR-APP-3,4`).
- Live capture: weight (stability indicator), length (mode check vs age), MUAC (manual + oedema).
- **Result screen** design rules (rough roadmap §3.1):
  1. Colour band **and** Hindi word first (top half). Never colour alone (CVD + greyscale photocopy).
  2. Numeric z-scores below the fold.
  3. Referral prompt is *advice the worker acts on*, not an instruction the app issues (`CON-5`):
     "इस बच्चे को ANM को दिखाने की सलाह दी जाती है".
  4. One tap to save and advance to the next child.
- Child history: growth curve vs WHO bands (`fl_chart`), previous visits.
- Parent growth card: preview, share via WhatsApp, print (`printing`).
- Usability session with 2 AWWs; redesign backlog captured.

### Entry criteria
- G2 signed off; frozen GATT spec available; bench unit accessible.

### Exit criteria / DoD — **Gate G3 (field-usable build)**
- [ ] Live weight/length values captured from the bench unit; reconnect and manual fallback work.
- [ ] Result screen passes accessibility rules (text+colour+icon, greyscale-safe, 48 dp targets).
- [ ] Growth curve renders per-child against WHO bands with correct sex/age reference.
- [ ] Parent card previews, prints, and shares via WhatsApp.
- [ ] Semester-1 build handed to 2 AWWs; usability findings logged (SUS + think-aloud).
- [ ] **Gate G3** signed off after the usability session.

### Risks
| Risk | Mitigation |
|---|---|
| BLE instability / dropouts mid-reading | Reconnect logic + manual entry fallback; field drop tests. |
| Result screen misread in the field | Colour+word+icon; test outdoors in daylight (`NFR`). |
| Referral wording implies liability | `CON-5` phrasing reviewed with clinical + AWW input. |

---

## Phase P4 — Sync, Security & Export

**Goal:** Durable offline-first sync that never blocks the UI, encrypted local storage, and export in
the exact Poshan Tracker column order.

### Scope (`FR-APP-12,13,16,17`; `FR-SRV-2,4,8`)
- **Sync** (rough roadmap §4): `capture → local write → outbox → UI returns immediately`.
  `workmanager` every 15 min + on connectivity change; batch ≤ 50 records; `POST /v1/sync/batch`.
  - Idempotency key = record UUID; server repeat = no-op (`FR-SRV-2`).
  - 200 → delete from outbox; 409 → conflict (last-write-wins by `updated_at`, superseded retained
    server-side, `FR-SRV-4`); 4xx → dead-letter surfaced in Settings; 5xx/timeout → exponential
    backoff (30 s → 1 h cap).
  - Sync **never** blocks UI; no network spinner during measurement (`FR-APP-13`, `CON-7`).
  - Failed records stay in outbox indefinitely; Settings shows backlog + last error.
- **Security**: SQLCipher-encrypted DB, PIN unlock (`FR-APP-16`), token storage via
  `flutter_secure_storage`.
- **Export**: CSV in Poshan Tracker column order (`FR-APP-12`), column order approved by an AWW.
- Home screen: device status, battery, calibration age, sync backlog, today's list (`FR-APP-17`).

### Entry criteria
- G3 signed off; server sync contract (`/v1/sync/batch`) agreed with backend.

### Exit criteria / DoD — **Gate G4 (security & export)**
- [ ] **500-record integrity test** passes, including forced app kills mid-batch (`NFR-9`) — no loss,
      no duplication (idempotency verified).
- [ ] Conflict path exercised: 409 applies last-write-wins; superseded version retained server-side.
- [ ] Dead-letter records surface in Settings with actionable error text.
- [ ] Local DB encrypted (SQLCipher); PIN gate enforced; tokens in secure storage.
- [ ] CSV export matches Poshan Tracker column order **exactly**, approved by an AWW.
- [ ] **Gate G4** signed off by security reviewer + AWW.

### Risks
| Risk | Mitigation |
|---|---|
| Data loss on crash mid-sync | Outbox durability + idempotency; kill-during-batch test. |
| Column order drift breaks import | Golden CSV fixture + AWW approval; regression test. |
| Key management for SQLCipher | Key derived from PIN + secure storage; documented rotation. |

---

## Phase P5 — Field Hardening & Validation

**Goal:** The app survives real field conditions and supports the formal agreement/validation study.

### Scope (`FR-APP-9,14`; `NFR-7,8`)
- Referral flow + follow-up: record `pending`/`attended`/`not_attended`/`unknown` on a later visit
  (`FR-APP-9`).
- Centre view: screened this month, flagged, overdue (`FR-APP-14`).
- Offline hardening: full airplane-mode end-to-end must pass.
- **Validation support**: app used in the agreement study; paired-record (device vs manual) export
  produced clean.
- **Usability iteration**: redesign from field observation; reduce taps per child; measure `NFR-7`,
  `NFR-8`.

### Entry criteria
- G4 signed off; study protocol and paired-measurement plan agreed.

### Exit criteria / DoD
- [ ] Airplane-mode end-to-end (register → capture → result → referral → export) passes.
- [ ] Referral outcomes recordable across visits and reflected in centre view.
- [ ] Agreement-study data collected clean; paired-record export validated against protocol.
- [ ] Taps-per-child measured before/after; `NFR-7`/`NFR-8` targets met and documented.

### Risks
| Risk | Mitigation |
|---|---|
| Field conditions unmodelled in lab | Field checklist: BLE drop, battery death mid-session, sun. |
| Study data contaminated by app bugs | Freeze build for study window; hotfix-only branch. |

---

## Phase P6 — Polish, Release & Handover

**Goal:** A stable, signed release an AWW can install and use unaided, with documentation in Hindi.

### Scope
- Crash fixes, empty states, all error messages in Hindi.
- Zero crashes across a 2-week field window (crash reporting instrumented).
- Signed release APK, install guide, Hindi user-manual sections.
- Device management + about in Settings; language toggle.

### Entry criteria
- P5 complete; validation study data collected.

### Exit criteria / DoD — **Gate G5 (release readiness)**
- [ ] Zero crashes observed across a 2-week field window.
- [ ] Signed release APK produced and reproducible from CI.
- [ ] Install guide + Hindi manual sections complete.
- [ ] An AWW installs and uses the app **unaided** in an observed session.
- [ ] **Gate G5** signed off by product owner → handover.

---

## Cross-cutting: Test Strategy (all phases)

| Level | What | Tool | Phase introduced |
|---|---|---|---|
| Unit | Z-score engine vs golden corpus | `flutter test`, golden JSON | P2 |
| Unit | Packet codec, CRC, age calc, 24-month boundary | `flutter test` | P2 |
| Unit | Repositories/DAOs, consent, soft-delete | `flutter test` | P1 |
| Widget | Result screen renders each classification correctly | `flutter_test` | P3 |
| Integration | capture → store → outbox → sync (mock server) | `integration_test` | P4 |
| Integration | 500-record sync + kill-mid-batch | `integration_test` | P4 |
| Manual | Airplane mode e2e; BLE drop; battery death mid-session | Field checklist | P3+ |
| Usability | SUS + think-aloud, 4–6 AWWs, two rounds | Recorded w/ consent | P3, P5 |

**Mandatory practice:** the mock BLE client (P2) is *schedule protection*, not a testing convenience.
Build it early and keep it working to handover so the team is never blocked by a broken load cell or
printer queue.

---

## Cross-cutting: Localisation & Accessibility (all phases)

- All user-facing strings in `hi.arb` from P0; lint fails the build on hardcoded text (`NFR-16`).
- **Hindi first, English fallback** — default locale `hi`.
- Devanagari vs Latin numerals decided **with the AWWs**, not the team (settle in W3–W6 interviews).
- Minimum touch target 48 dp; base font 16 sp; honour system scaling.
- Every colour-coded status also carries text or an icon.
- Test on the **actual target phone in outdoor daylight** — lab screens wash out in a courtyard.

---

## Cross-cutting: Definition of Done (every ticket)

A change is Done only when:
1. Code passes `dart format`, `flutter analyze`, and all tests in CI.
2. New user-facing strings are in `hi.arb` (and `en.arb` fallback).
3. Accessibility rules hold (contrast, 48 dp, text+colour+icon).
4. Offline behaviour is correct (no UI block, no silent data loss).
5. Relevant `FR-*`/`NFR-*` acceptance criteria are demonstrably met.
6. Tests added at the appropriate level (unit/widget/integration).

---

## Milestone summary

| Milestone | Phase | Gate | Semester target |
|---|---|---|---|
| Project builds on target phone | P0 | G0 | Sem 1, W2 |
| Data model frozen | P0/P1 | G1 | Sem 1, W4 |
| Engine matches WHO reference | P2 | G2 | Sem 1, W8 |
| Field-usable Sem-1 build | P3 | G3 | Sem 1, W16 |
| Sync + security + export | P4 | G4 | Sem 2, W4 |
| Validation study supported | P5 | — | Sem 2, W8 |
| Signed release + handover | P6 | G5 | Sem 2, W14 |
